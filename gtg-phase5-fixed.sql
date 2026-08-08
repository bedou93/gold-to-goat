-- ═══════════════════════════════════════════════════════════════
-- GTG PHASE 5 — SQL Corrigé
-- ═══════════════════════════════════════════════════════════════


-- ══════════════════════════════════════════════════════
-- PARTIE A — BONUS TACTIQUES
-- ══════════════════════════════════════════════════════

create table if not exists public.bonus_types (
  id          text primary key,
  nom         text not null,
  description text not null,
  icone       text not null,
  effet       jsonb not null,
  usage_max   int default 1,
  phase       text default 'match'
              check(phase in ('match','mercato','saison')),
  actif       boolean default true
);

alter table public.bonus_types enable row level security;
create policy "Bonus types select" on public.bonus_types for select using (true);
create policy "Bonus types insert" on public.bonus_types for insert with check (auth.role() = 'service_role');
create policy "Bonus types update" on public.bonus_types for update using (auth.role() = 'service_role');

insert into public.bonus_types values
('capitaine',
 'Capitaine',
 '×2 buts réels pour 1 joueur désigné',
 '⭐',
 '{"type":"multiplicateur","facteur":2,"cible":"joueur_unique"}',
 3, 'match', true),
('sniper',
 'Sniper',
 'Ton meilleur ATT gagne +1.5 note pour les duels GTG ce match',
 '🎯',
 '{"type":"note_boost","ligne":"ATT","valeur":1.5}',
 2, 'match', true),
('pressing',
 'Pressing Total',
 'Tes milieux +0.8, MID adverses −0.8 pour ce match',
 '💨',
 '{"type":"note_boost_bilateral","ligne_ami":"MID","ami_valeur":0.8,"ennemi_valeur":-0.8}',
 2, 'match', true),
('contre_attaque',
 'Contre-Attaque',
 'Tes ATT ignorent la ligne MID adverse',
 '⚡',
 '{"type":"skip_ligne","ligne_ignoree":"MID"}',
 2, 'match', true),
('catenaccio_plus',
 'Catenaccio+',
 'Catenaccio actif dès DEF à 3, annule 2 buts si moy DEF > 8.0',
 '🛡️',
 '{"type":"catenaccio_ameliore","def_min":3,"buts_max":2,"note_min_def":8.0}',
 2, 'match', true),
('mur',
 'Le Mur',
 'Ton GK gagne +2.0 note pour ce match',
 '🧱',
 '{"type":"note_boost","ligne":"GK","valeur":2.0}',
 2, 'match', true),
('bouclier_goat',
 'Bouclier GOAT',
 'Protège 1 joueur absent : 6.0 au lieu de 2.5',
 '🔮',
 '{"type":"protection_absence","note_remplacement":6.0}',
 3, 'match', true),
('transfert_star',
 'Star du Mercato',
 '+30M€ bonus au budget du prochain tour',
 '💸',
 '{"type":"budget_bonus","montant":30000000000}',
 1, 'mercato', true),
('scout',
 'Scout Élite',
 'Vois les enchères adverses pour 1 joueur au prochain tour',
 '🕵️',
 '{"type":"info_encheres","nb_joueurs":1}',
 1, 'mercato', true)
on conflict(id) do update set
  nom         = excluded.nom,
  description = excluded.description,
  effet       = excluded.effet;


-- ── BONUS PAR ÉQUIPE ──────────────────────────────────
create table if not exists public.team_bonus (
  id          uuid default uuid_generate_v4() primary key,
  team_id     uuid references public.teams(id) on delete cascade not null,
  league_id   uuid references public.leagues(id) not null,
  bonus_id    text references public.bonus_types(id) not null,
  uses_left   int not null default 1,
  uses_total  int not null default 1,
  saison      text default '2025-26',
  created_at  timestamptz default now(),
  unique(team_id, bonus_id, saison)
);

alter table public.team_bonus enable row level security;
create policy "Team bonus select" on public.team_bonus
  for select using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );
create policy "Team bonus insert" on public.team_bonus
  for insert with check (auth.role() = 'service_role');
create policy "Team bonus update" on public.team_bonus
  for update using (auth.role() = 'service_role');


-- ── UTILISATIONS DE BONUS ─────────────────────────────
create table if not exists public.bonus_uses (
  id              uuid default uuid_generate_v4() primary key,
  team_id         uuid references public.teams(id) not null,
  league_id       uuid references public.leagues(id) not null,
  match_id        uuid references public.matches(id),
  bonus_id        text references public.bonus_types(id) not null,
  cible_player_id uuid references public.players(id),
  journee         int,
  tour_enchere    int,
  resultat        jsonb,
  created_at      timestamptz default now()
);

alter table public.bonus_uses enable row level security;
create policy "Bonus uses select own" on public.bonus_uses
  for select using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );
create policy "Bonus uses insert" on public.bonus_uses
  for insert with check (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );

alter publication supabase_realtime add table public.bonus_uses;


-- ── FONCTION : DISTRIBUER BONUS EN DÉBUT DE SAISON ───
create or replace function public.distribuer_bonus_saison(
  p_league_id uuid,
  p_saison    text default '2025-26'
)
returns void as $$
declare
  team_rec  record;
  bonus_rec record;
begin
  for team_rec in
    select id from public.teams where league_id = p_league_id
  loop
    for bonus_rec in
      select * from public.bonus_types where actif = true
    loop
      insert into public.team_bonus
        (team_id, league_id, bonus_id, uses_left, uses_total, saison)
      values
        (team_rec.id, p_league_id, bonus_rec.id,
         bonus_rec.usage_max, bonus_rec.usage_max, p_saison)
      on conflict (team_id, bonus_id, saison) do nothing;
    end loop;
  end loop;
end;
$$ language plpgsql security definer;


-- ── FONCTION : APPLIQUER UN BONUS ────────────────────
create or replace function public.appliquer_bonus(
  p_team_id       uuid,
  p_match_id      uuid,
  p_bonus_id      text,
  p_cible_id      uuid default null
)
returns jsonb as $$
declare
  bonus_rec      record;
  team_bonus_rec record;
  match_rec      record;
  v_journee      int;
  v_league_id    uuid;
begin
  select * into bonus_rec from public.bonus_types where id = p_bonus_id;
  if not found then
    return jsonb_build_object('error','Bonus introuvable');
  end if;

  select * into team_bonus_rec
  from public.team_bonus
  where team_id = p_team_id and bonus_id = p_bonus_id and uses_left > 0;
  if not found then
    return jsonb_build_object('error','Bonus épuisé ou non disponible');
  end if;

  if p_match_id is not null then
    select journee into v_journee
    from public.matches where id = p_match_id;
  end if;

  select league_id into v_league_id
  from public.teams where id = p_team_id;

  update public.team_bonus
  set uses_left = uses_left - 1
  where team_id = p_team_id and bonus_id = p_bonus_id;

  insert into public.bonus_uses
    (team_id, league_id, match_id, bonus_id, cible_player_id, journee)
  values
    (p_team_id, v_league_id, p_match_id, p_bonus_id, p_cible_id, v_journee);

  return jsonb_build_object(
    'success',   true,
    'bonus_id',  p_bonus_id,
    'uses_left', team_bonus_rec.uses_left - 1,
    'effet',     bonus_rec.effet
  );
end;
$$ language plpgsql security definer;


-- ══════════════════════════════════════════════════════
-- PARTIE B — TRANSFERTS MID-SAISON & PRÊTS
-- ══════════════════════════════════════════════════════

create table if not exists public.mercato_midseason (
  id              uuid default uuid_generate_v4() primary key,
  league_id       uuid references public.leagues(id) on delete cascade not null,
  statut          text default 'ferme'
                  check(statut in ('ferme','ventes','encheres_t1','encheres_t2','encheres_t3','termine')),
  date_ouverture  timestamptz,
  date_fermeture  timestamptz,
  budget_bonus    bigint default 0,
  created_at      timestamptz default now(),
  unique(league_id)
);

alter table public.mercato_midseason enable row level security;
create policy "Mercato mid select" on public.mercato_midseason for select using (true);
create policy "Mercato mid insert" on public.mercato_midseason for insert with check (auth.role() = 'service_role');
create policy "Mercato mid update" on public.mercato_midseason for update using (auth.role() = 'service_role');


create table if not exists public.transfers (
  id              uuid default uuid_generate_v4() primary key,
  league_id       uuid references public.leagues(id) not null,
  player_id       uuid references public.players(id) not null,
  from_team_id    uuid references public.teams(id),
  to_team_id      uuid references public.teams(id),
  prix            bigint not null,
  type            text not null
                  check(type in ('vente_libre','achat_encheres','pret','pret_option_achat','pret_gratuit')),
  statut          text default 'en_attente'
                  check(statut in ('en_attente','accepte','refuse','expire')),
  option_achat    bigint,
  duree_pret      int,
  journee_retour  int,
  note_au_moment  numeric(3,1),
  created_at      timestamptz default now(),
  resolved_at     timestamptz
);

alter table public.transfers enable row level security;
create policy "Transfers select" on public.transfers
  for select using (
    exists(
      select 1 from public.teams
      where league_id = transfers.league_id and coach_id = auth.uid()
    )
  );
create policy "Transfers insert" on public.transfers
  for insert with check (
    auth.uid() = (select coach_id from public.teams where id = from_team_id)
  );

alter publication supabase_realtime add table public.transfers;


create table if not exists public.transfer_offers (
  id              uuid default uuid_generate_v4() primary key,
  transfer_id     uuid references public.transfers(id) on delete cascade not null,
  from_team_id    uuid references public.teams(id) not null,
  to_team_id      uuid references public.teams(id) not null,
  montant         bigint,
  message         text,
  statut          text default 'en_attente'
                  check(statut in ('en_attente','accepte','refuse','contre_offre')),
  created_at      timestamptz default now()
);

alter table public.transfer_offers enable row level security;
create policy "Transfer offers select" on public.transfer_offers
  for select using (
    auth.uid() in (
      select coach_id from public.teams
      where id = from_team_id or id = to_team_id
    )
  );
create policy "Transfer offers insert" on public.transfer_offers
  for insert with check (
    auth.uid() = (select coach_id from public.teams where id = from_team_id)
  );

alter publication supabase_realtime add table public.transfer_offers;


-- ── FONCTION : VENDRE UN JOUEUR ───────────────────────
create or replace function public.vendre_joueur(
  p_team_id   uuid,
  p_player_id uuid,
  p_league_id uuid
)
returns jsonb as $$
declare
  v_cote_tm   bigint;
  v_nom       text;
  v_coach_id  uuid;
begin
  select p.cote_tm, p.nom into v_cote_tm, v_nom
  from public.squads s
  join public.players p on p.id = s.player_id
  where s.team_id = p_team_id
    and s.player_id = p_player_id
    and s.league_id = p_league_id;

  if not found then
    return jsonb_build_object('error','Joueur non trouvé dans ton effectif');
  end if;

  select coach_id into v_coach_id from public.teams where id = p_team_id;

  update public.teams
  set budget = budget + v_cote_tm
  where id = p_team_id;

  delete from public.squads
  where team_id = p_team_id
    and player_id = p_player_id
    and league_id = p_league_id;

  insert into public.transfers
    (league_id, player_id, from_team_id, prix, type, statut, note_au_moment)
  values
    (p_league_id, p_player_id, p_team_id,
     v_cote_tm, 'vente_libre', 'accepte',
     v_cote_tm::float / 1e9);

  insert into public.notifications (user_id, type, titre, message)
  values (
    v_coach_id,
    'transfert_vente',
    '💸 Vente confirmée · ' || v_nom,
    v_nom || ' vendu pour '
      || (v_cote_tm::float / 1e9)::numeric(10,1)::text
      || 'M€ · Budget mis à jour'
  );

  return jsonb_build_object(
    'success', true,
    'joueur',  v_nom,
    'prix_m',  (v_cote_tm::float / 1e9)::numeric(10,1)
  );
end;
$$ language plpgsql security definer;


-- ══════════════════════════════════════════════════════
-- PARTIE C — PLAY-OFFS
-- ══════════════════════════════════════════════════════

create table if not exists public.playoffs (
  id                  uuid default uuid_generate_v4() primary key,
  league_id           uuid references public.leagues(id) on delete cascade unique,
  actif               boolean default false,
  format              text default '4'
                      check(format in ('2','4','6','8')),
  statut              text default 'non_commence'
                      check(statut in ('non_commence','quarts','demis','finale','termine')),
  prime_participation bigint default 0,
  prime_victoire      bigint default 0,
  prime_champion      bigint default 0,
  created_at          timestamptz default now()
);

alter table public.playoffs enable row level security;
create policy "Playoffs select" on public.playoffs for select using (true);
create policy "Playoffs insert" on public.playoffs
  for insert with check (
    auth.uid() = (select admin_id from public.leagues where id = league_id)
  );
create policy "Playoffs update" on public.playoffs
  for update using (
    auth.uid() = (select admin_id from public.leagues where id = league_id)
  );

alter publication supabase_realtime add table public.playoffs;


create table if not exists public.playoff_matches (
  id              uuid default uuid_generate_v4() primary key,
  playoff_id      uuid references public.playoffs(id) on delete cascade not null,
  league_id       uuid references public.leagues(id) not null,
  round           text not null
                  check(round in ('quart_finale','demi_finale','finale','3eme_place')),
  home_team_id    uuid references public.teams(id),
  away_team_id    uuid references public.teams(id),
  score_home      int,
  score_away      int,
  buts_reels_h    int default 0,
  buts_reels_a    int default 0,
  buts_gtg_h      int default 0,
  buts_gtg_a      int default 0,
  winner_id       uuid references public.teams(id),
  journee_ligue1  int,
  statut          text default 'a_planifier'
                  check(statut in ('a_planifier','programme','en_cours','termine')),
  match_aller_id  uuid references public.playoff_matches(id),
  created_at      timestamptz default now()
);

alter table public.playoff_matches enable row level security;
create policy "Playoff matchs select" on public.playoff_matches for select using (true);
create policy "Playoff matchs insert" on public.playoff_matches
  for insert with check (auth.role() = 'service_role');
create policy "Playoff matchs update" on public.playoff_matches
  for update using (auth.role() = 'service_role');

alter publication supabase_realtime add table public.playoff_matches;


-- ── FONCTION : GÉNÉRER LE TABLEAU DES PLAY-OFFS ──────
-- Corrigé : uuid[] au lieu de record[]
create or replace function public.generer_playoffs(
  p_league_id uuid,
  p_format    text default '4'
)
returns jsonb as $$
declare
  playoff_id  uuid;
  seeds       uuid[];
  nb          int;
begin
  nb := p_format::int;

  -- Récupérer les N premiers IDs d'équipes classées
  select array_agg(team_id order by rang)
  into seeds
  from (
    select team_id, rang
    from public.classement
    where league_id = p_league_id
    order by rang
    limit nb
  ) sub;

  if seeds is null or array_length(seeds, 1) < nb then
    return jsonb_build_object('error', 'Pas assez d''équipes qualifiées');
  end if;

  -- Créer ou mettre à jour le playoff
  insert into public.playoffs (league_id, format, actif)
  values (p_league_id, p_format, true)
  on conflict (league_id) do update
    set actif = true, format = p_format
  returning id into playoff_id;

  -- Générer les matchs selon le format
  if p_format = '2' then
    insert into public.playoff_matches
      (playoff_id, league_id, round, home_team_id, away_team_id)
    values
      (playoff_id, p_league_id, 'finale', seeds[1], seeds[2]);

  elsif p_format = '4' then
    insert into public.playoff_matches
      (playoff_id, league_id, round, home_team_id, away_team_id)
    values
      (playoff_id, p_league_id, 'demi_finale', seeds[1], seeds[4]),
      (playoff_id, p_league_id, 'demi_finale', seeds[2], seeds[3]);

  elsif p_format = '6' then
    insert into public.playoff_matches
      (playoff_id, league_id, round, home_team_id, away_team_id)
    values
      (playoff_id, p_league_id, 'quart_finale', seeds[3], seeds[6]),
      (playoff_id, p_league_id, 'quart_finale', seeds[4], seeds[5]),
      (playoff_id, p_league_id, 'demi_finale',  seeds[1], null),
      (playoff_id, p_league_id, 'demi_finale',  seeds[2], null);

  elsif p_format = '8' then
    insert into public.playoff_matches
      (playoff_id, league_id, round, home_team_id, away_team_id)
    values
      (playoff_id, p_league_id, 'quart_finale', seeds[1], seeds[8]),
      (playoff_id, p_league_id, 'quart_finale', seeds[2], seeds[7]),
      (playoff_id, p_league_id, 'quart_finale', seeds[3], seeds[6]),
      (playoff_id, p_league_id, 'quart_finale', seeds[4], seeds[5]);
  end if;

  -- Notifier les qualifiés
  insert into public.notifications (user_id, type, titre, message, data)
  select
    t.coach_id,
    'playoffs_qualification',
    '🏆 Tu es qualifié pour les play-offs !',
    'Les play-offs débutent après la saison régulière.',
    jsonb_build_object('playoff_id', playoff_id, 'league_id', p_league_id)
  from public.teams t
  where t.id = any(seeds);

  return jsonb_build_object(
    'success',             true,
    'playoff_id',          playoff_id,
    'format',              p_format,
    'equipes_qualifiees',  nb
  );
end;
$$ language plpgsql security definer;


-- ── FONCTION : DISTRIBUER RÉCOMPENSES PLAY-OFFS ───────
create or replace function public.distribuer_recompenses_playoffs(
  p_playoff_id  uuid,
  p_champion_id uuid
)
returns void as $$
declare
  playoff_rec record;
  match_rec   record;
begin
  select * into playoff_rec from public.playoffs where id = p_playoff_id;

  -- Prime par match joué
  for match_rec in
    select home_team_id as team_id, winner_id
    from public.playoff_matches
    where playoff_id = p_playoff_id and statut = 'termine'
    union all
    select away_team_id, winner_id
    from public.playoff_matches
    where playoff_id = p_playoff_id and statut = 'termine'
  loop
    update public.teams
    set budget = budget + playoff_rec.prime_participation
    where id = match_rec.team_id;

    if match_rec.team_id = match_rec.winner_id then
      update public.teams
      set budget = budget + playoff_rec.prime_victoire
      where id = match_rec.team_id;
    end if;
  end loop;

  -- Prime champion
  if playoff_rec.prime_champion > 0 then
    update public.teams
    set budget = budget + playoff_rec.prime_champion
    where id = p_champion_id;
  end if;

  -- Notification champion
  insert into public.notifications (user_id, type, titre, message)
  select coach_id,
    'champion',
    '🏆 CHAMPION GTG !',
    'Félicitations ! Tu remportes le titre de ta ligue ! 🎉'
  from public.teams
  where id = p_champion_id;
end;
$$ language plpgsql security definer;


-- ── INDEX ─────────────────────────────────────────────
create index if not exists idx_team_bonus_team    on public.team_bonus(team_id);
create index if not exists idx_bonus_uses_match   on public.bonus_uses(match_id);
create index if not exists idx_transfers_league   on public.transfers(league_id);
create index if not exists idx_transfers_player   on public.transfers(player_id);
create index if not exists idx_playoff_matches_pl on public.playoff_matches(playoff_id);


-- ═══════════════════════════════════════════════════════════════
-- ✅ PHASE 5 SQL CORRIGÉ ET TERMINÉ
-- ═══════════════════════════════════════════════════════════════
