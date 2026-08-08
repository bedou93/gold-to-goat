-- ═══════════════════════════════════════════════════════════════
-- GTG PHASE 2 — SQL Corrigé
-- ═══════════════════════════════════════════════════════════════


-- ── 1. ACTIVER REALTIME ───────────────────────────────────────
alter publication supabase_realtime add table public.bids;
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.teams;
alter publication supabase_realtime add table public.leagues;


-- ── 2. VUE : STATUT DU MERCATO PAR LIGUE ─────────────────────
create or replace view public.mercato_status as
select
  b.league_id,
  b.tour,
  count(distinct b.team_id)                                    as total_teams,
  count(distinct b.team_id) filter (where b.submitted = true)  as teams_submitted,
  count(*) filter (where b.submitted = true)                    as total_bids_submitted,
  max(b.updated_at)                                             as last_activity
from public.bids b
group by b.league_id, b.tour;


-- ── 3. FONCTION : VÉRIFIER SI TOUS LES COACHES ONT SOUMIS ────
create or replace function public.check_all_submitted(
  p_league_id uuid,
  p_tour      int
)
returns boolean as $$
declare
  total_teams     int;
  teams_submitted int;
begin
  select count(*) into total_teams
  from public.teams
  where league_id = p_league_id;

  select count(distinct team_id) into teams_submitted
  from public.bids
  where league_id = p_league_id
    and tour = p_tour
    and submitted = true;

  return teams_submitted >= total_teams;
end;
$$ language plpgsql security definer;


-- ── 4. FONCTION : RÉSOLUTION DES ENCHÈRES ────────────────────
-- Tous les declare sont en haut de la fonction (règle PL/pgSQL)

create or replace function public.resoudre_tour(
  p_league_id uuid,
  p_tour      int
)
returns jsonb as $$
declare
  player_rec    record;
  winner_bid    record;
  bid_rec       record;
  results       jsonb := '[]'::jsonb;
  max_montant   bigint;
  tied_count    int;
begin
  -- Vérifier que tous ont soumis
  if not public.check_all_submitted(p_league_id, p_tour) then
    return jsonb_build_object('error', 'Tous les coaches n''ont pas encore soumis');
  end if;

  for player_rec in
    select distinct player_id
    from public.bids
    where league_id = p_league_id
      and tour = p_tour
      and submitted = true
    order by player_id
  loop

    -- Enchère gagnante (max montant, puis plus ancien = 1er enchérisseur)
    select b.*, t.coach_id
    into winner_bid
    from public.bids b
    join public.teams t on t.id = b.team_id
    where b.league_id = p_league_id
      and b.tour = p_tour
      and b.player_id = player_rec.player_id
      and b.submitted = true
    order by b.montant desc, b.created_at asc
    limit 1;

    -- Montant maximum pour ce joueur
    select max(montant) into max_montant
    from public.bids
    where league_id = p_league_id
      and tour = p_tour
      and player_id = player_rec.player_id
      and submitted = true;

    -- Nombre d'enchères à ce montant max (égalités)
    select count(*) into tied_count
    from public.bids
    where league_id = p_league_id
      and tour = p_tour
      and player_id = player_rec.player_id
      and submitted = true
      and montant = max_montant;

    -- Traiter chaque enchère pour ce joueur
    for bid_rec in
      select b.*, t.coach_id, p.nom as player_nom
      from public.bids b
      join public.teams t on t.id = b.team_id
      join public.players p on p.id = b.player_id
      where b.league_id = p_league_id
        and b.tour = p_tour
        and b.player_id = player_rec.player_id
        and b.submitted = true
    loop

      if bid_rec.id = winner_bid.id then
        -- GAGNANT
        update public.bids
        set statut = case when tied_count > 1 then 'egalite_gagnant' else 'gagnant' end
        where id = bid_rec.id;

        insert into public.squads (team_id, player_id, league_id, prix_achat)
        values (bid_rec.team_id, bid_rec.player_id, p_league_id, bid_rec.montant)
        on conflict (player_id, league_id) do nothing;

        update public.teams
        set budget = budget - bid_rec.montant
        where id = bid_rec.team_id;

        insert into public.notifications (user_id, type, titre, message, data)
        values (
          bid_rec.coach_id,
          'enchere_gagnee',
          '🏆 ' || bid_rec.player_nom || ' est dans ton effectif !',
          'Enchère remportée'
            || case when tied_count > 1 then ' (égalité — 1er enchérisseur)' else '' end
            || ' pour ' || (bid_rec.montant::float / 1e9)::numeric(10,1)::text || 'M€',
          jsonb_build_object(
            'player_id',  bid_rec.player_id,
            'player_nom', bid_rec.player_nom,
            'montant',    bid_rec.montant,
            'tour',       p_tour,
            'tie',        tied_count > 1
          )
        );

        results := results || jsonb_build_object(
          'player_id',     bid_rec.player_id,
          'winner_team_id',bid_rec.team_id,
          'winning_bid',   bid_rec.montant,
          'tie',           tied_count > 1
        );

      else
        -- PERDANT
        update public.bids
        set statut = case when tied_count > 1 then 'egalite_perdant' else 'perdant' end
        where id = bid_rec.id;

        insert into public.notifications (user_id, type, titre, message, data)
        values (
          bid_rec.coach_id,
          'enchere_perdue',
          '❌ ' || bid_rec.player_nom || ' remporté par un autre coach',
          'Ta mise de ' || (bid_rec.montant::float / 1e9)::numeric(10,1)::text
            || 'M€ était insuffisante.'
            || case when tied_count > 1 then ' Égalité — concurrent plus rapide.' else '' end
            || ' Disponible au tour ' || (p_tour + 1)::text,
          jsonb_build_object(
            'player_id',    bid_rec.player_id,
            'player_nom',   bid_rec.player_nom,
            'ta_mise',      bid_rec.montant,
            'mise_gagnante',max_montant,
            'tour_suivant', p_tour + 1
          )
        );
      end if;

    end loop;
  end loop;

  -- Ouvrir le tour suivant
  if p_tour < 3 then
    update public.leagues set statut = 'mercato' where id = p_league_id;

    insert into public.notifications (user_id, type, titre, message, data)
    select
      t.coach_id,
      'tour_ouvert',
      '⚡ Tour ' || (p_tour + 1) || ' d''enchères ouvert !',
      'Les joueurs non-attribués sont disponibles. Budget restant mis à jour.',
      jsonb_build_object('tour', p_tour + 1, 'league_id', p_league_id)
    from public.teams t
    where t.league_id = p_league_id;
  else
    update public.leagues set statut = 'saison' where id = p_league_id;
  end if;

  return jsonb_build_object(
    'success',    true,
    'tour',       p_tour,
    'results',    results,
    'next_tour',  case when p_tour < 3 then p_tour + 1 else null end
  );

exception when others then
  return jsonb_build_object('error', SQLERRM);
end;
$$ language plpgsql security definer;


-- ── 5. TRIGGER : RÉSOLUTION AUTOMATIQUE ──────────────────────
create or replace function public.trigger_check_resolution()
returns trigger as $$
declare
  should_resolve boolean;
begin
  should_resolve := public.check_all_submitted(new.league_id, new.tour);
  if should_resolve then
    perform pg_notify(
      'gtg_resolution',
      json_build_object(
        'league_id', new.league_id,
        'tour',      new.tour,
        'event',     'all_submitted'
      )::text
    );
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists on_bid_submitted on public.bids;
create trigger on_bid_submitted
  after update of submitted on public.bids
  for each row
  when (new.submitted = true and old.submitted = false)
  execute function public.trigger_check_resolution();


-- ── 6. FONCTION : GÉNÉRER LE CALENDRIER ──────────────────────
create or replace function public.generer_calendrier(
  p_league_id uuid
)
returns int as $$
declare
  teams         uuid[];
  n             int;
  rounds        int;
  i             int;
  r             int;
  k             int;
  home          uuid;
  away          uuid;
  journee       int := 1;
  matches_count int := 0;
  last_team     uuid;
  aller_rec     record;
begin
  select array_agg(id order by random())
  into teams
  from public.teams
  where league_id = p_league_id;

  n := array_length(teams, 1);
  if n < 2 then
    raise exception 'Minimum 2 équipes requises';
  end if;

  rounds := n - 1;

  for r in 1..rounds loop
    for i in 1..floor(n/2)::int loop
      home := teams[i];
      away := teams[n - i + 1];
      insert into public.matches (league_id, home_team_id, away_team_id, journee)
      values (p_league_id, home, away, journee);
      matches_count := matches_count + 1;
    end loop;
    journee := journee + 1;

    -- Rotation round-robin
    last_team := teams[n];
    for k in reverse n..2 loop
      teams[k] := teams[k-1];
    end loop;
    teams[2] := last_team;
  end loop;

  -- Phase retour
  for aller_rec in
    select * from public.matches
    where league_id = p_league_id
    order by journee
  loop
    insert into public.matches (league_id, home_team_id, away_team_id, journee)
    values (
      p_league_id,
      aller_rec.away_team_id,
      aller_rec.home_team_id,
      aller_rec.journee + rounds
    );
    matches_count := matches_count + 1;
  end loop;

  return matches_count;
end;
$$ language plpgsql security definer;


-- ── 7. VUES SÉCURISÉES ────────────────────────────────────────
create or replace view public.my_bids as
select b.*
from public.bids b
join public.teams t on t.id = b.team_id
where t.coach_id = auth.uid();

create or replace view public.bid_results as
select
  b.league_id,
  b.player_id,
  b.tour,
  b.statut,
  p.nom   as player_nom,
  p.club,
  p.poste,
  case when t.coach_id = auth.uid() then b.montant else null end as montant,
  t.nom   as team_nom,
  case when t.coach_id = auth.uid() then true else false end     as is_mine
from public.bids b
join public.players p on p.id = b.player_id
join public.teams t   on t.id = b.team_id
where b.statut != 'en_attente';


-- ── 8. INDEX ──────────────────────────────────────────────────
create index if not exists idx_bids_submitted  on public.bids(league_id, tour, submitted);
create index if not exists idx_notifs_unread   on public.notifications(user_id, lue);
create index if not exists idx_matches_journee on public.matches(league_id, journee);


-- ═══════════════════════════════════════════════════════════════
-- ✅ PHASE 2 SQL CORRIGÉ ET TERMINÉ
-- ═══════════════════════════════════════════════════════════════
