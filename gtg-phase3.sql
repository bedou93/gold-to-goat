-- ═══════════════════════════════════════════════════════════════
-- GTG PHASE 3 — SQL
-- gtg-phase3.sql
-- ───────────────────────────────────────────────────────────────
-- Colle dans Supabase SQL Editor → Run
-- ═══════════════════════════════════════════════════════════════


-- ── 1. TABLE : JOURNÉES L1 ────────────────────────────────────
-- Suivi des journées réelles de Ligue 1

create table if not exists public.journees (
  id            uuid default uuid_generate_v4() primary key,
  numero        int not null unique,              -- ex: 32
  date_debut    timestamptz,                      -- date du premier match
  date_fin      timestamptz,                      -- date du dernier match
  statut        text default 'a_venir'
                check (statut in ('a_venir','en_cours','terminee')),
  notes_ready   boolean default false,            -- notes calculées ?
  gtg_ready     boolean default false,            -- résultats GTG calculés ?
  created_at    timestamptz default now()
);

-- Insérer les journées 2025/26 restantes
insert into public.journees (numero, statut) values
  (32, 'terminee'), (33, 'a_venir'), (34, 'a_venir'),
  (35, 'a_venir'), (36, 'a_venir'), (37, 'a_venir'), (38, 'a_venir')
on conflict (numero) do nothing;

alter table public.journees enable row level security;
create policy "Journees visibles par tous" on public.journees for select using (true);


-- ── 2. TABLE : NOTES HISTORIQUES JOUEURS ─────────────────────
-- Garde une trace des notes par journée (pour les graphiques)

create table if not exists public.player_notes_history (
  id          uuid default uuid_generate_v4() primary key,
  player_id   uuid references public.players(id) on delete cascade not null,
  journee     int not null,
  note        numeric(3,1) not null,
  buts        int default 0,
  passes      int default 0,
  minutes     int default 0,
  titulaire   boolean default true,
  created_at  timestamptz default now(),
  unique(player_id, journee)
);

create index if not exists idx_notes_history_player on public.player_notes_history(player_id);
create index if not exists idx_notes_history_journee on public.player_notes_history(journee);

alter table public.player_notes_history enable row level security;
create policy "Historique visible par tous" on public.player_notes_history for select using (true);
create policy "Service modifie historique"  on public.player_notes_history
  for all using (auth.role() = 'service_role');


-- ── 3. TABLE : RÉSULTATS GTG PAR JOURNÉE ─────────────────────
-- Détail de chaque confrontation

create table if not exists public.match_results (
  id              uuid default uuid_generate_v4() primary key,
  match_id        uuid references public.matches(id) on delete cascade not null unique,
  journee         int not null,
  league_id       uuid references public.leagues(id) not null,
  -- Scores
  score_home      int default 0,
  score_away      int default 0,
  buts_reels_h    int default 0,
  buts_reels_a    int default 0,
  buts_gtg_h      int default 0,
  buts_gtg_a      int default 0,
  catenaccio_h    int default 0,   -- buts annulés par catenaccio home
  catenaccio_a    int default 0,
  -- Duels
  duels_won_h     int default 0,
  duels_won_a     int default 0,
  duels_total_h   int default 0,
  duels_total_a   int default 0,
  -- Notes moyennes
  note_moy_h      numeric(3,1),
  note_moy_a      numeric(3,1),
  created_at      timestamptz default now()
);

alter table public.match_results enable row level security;
create policy "Resultats visibles par tous" on public.match_results for select using (true);


-- ── 4. FONCTION : UPDATE CLASSEMENT ──────────────────────────
-- Appelée par le serveur Node.js après chaque confrontation

create or replace function public.update_classement(
  p_home_team_id    uuid,
  p_away_team_id    uuid,
  p_home_points     int,
  p_away_points     int,
  p_home_buts_pour  int,
  p_home_buts_contre int,
  p_away_buts_pour  int,
  p_away_buts_contre int
)
returns void as $$
begin
  update public.teams
  set
    points      = points + p_home_points,
    buts_pour   = buts_pour + p_home_buts_pour,
    buts_contre = buts_contre + p_home_buts_contre
  where id = p_home_team_id;

  update public.teams
  set
    points      = points + p_away_points,
    buts_pour   = buts_pour + p_away_buts_pour,
    buts_contre = buts_contre + p_away_buts_contre
  where id = p_away_team_id;
end;
$$ language plpgsql security definer;


-- ── 5. VUE : CLASSEMENT PAR LIGUE ────────────────────────────

create or replace view public.classement as
select
  t.league_id,
  t.id          as team_id,
  t.nom         as team_nom,
  p.pseudo      as coach_pseudo,
  t.points,
  t.buts_pour,
  t.buts_contre,
  t.buts_pour - t.buts_contre as diff_buts,
  count(m.id) filter (where
    (m.home_team_id = t.id and m.score_home > m.score_away) or
    (m.away_team_id = t.id and m.score_away > m.score_home)
  ) as victoires,
  count(m.id) filter (where
    m.score_home = m.score_away and
    (m.home_team_id = t.id or m.away_team_id = t.id)
  ) as nuls,
  count(m.id) filter (where
    (m.home_team_id = t.id and m.score_home < m.score_away) or
    (m.away_team_id = t.id and m.score_away < m.score_home)
  ) as defaites,
  count(m.id) filter (where
    m.statut = 'termine' and
    (m.home_team_id = t.id or m.away_team_id = t.id)
  ) as matchs_joues,
  row_number() over (
    partition by t.league_id
    order by t.points desc, (t.buts_pour - t.buts_contre) desc, t.buts_pour desc
  ) as rang
from public.teams t
join public.profiles p on p.id = t.coach_id
left join public.matches m on
  m.league_id = t.league_id and
  (m.home_team_id = t.id or m.away_team_id = t.id)
group by t.id, t.league_id, t.nom, p.pseudo, t.points, t.buts_pour, t.buts_contre;


-- ── 6. VUE : PERFORMANCES JOUEURS SAISON ─────────────────────

create or replace view public.player_stats_saison as
select
  p.id,
  p.nom,
  p.club,
  p.poste,
  p.note_actuelle,
  p.note_moyenne,
  p.buts_saison,
  p.passes_saison,
  p.cote_tm,
  p.cote_prev,
  -- Tendance (dernière note vs note il y a 4 journées)
  p.note_actuelle - coalesce(
    (select note from public.player_notes_history
     where player_id = p.id
     order by journee desc
     offset 4 limit 1), p.note_moyenne
  ) as tendance,
  -- Pourcentage de sélection
  (select count(*) from public.squads where player_id = p.id)::float /
  nullif((select count(*) from public.leagues where statut in ('saison','terminee')), 0) * 100
  as pct_selection
from public.players p
where p.actif = true;


-- ── 7. TABLE : LOGS PIPELINE ─────────────────────────────────
-- Pour suivre les exécutions du serveur Node.js

create table if not exists public.pipeline_logs (
  id          uuid default uuid_generate_v4() primary key,
  journee     int,
  type        text,         -- 'notes'|'gtg'|'classement'|'error'
  message     text,
  details     jsonb,
  duration_ms int,
  created_at  timestamptz default now()
);

alter table public.pipeline_logs enable row level security;
-- Seulement l'admin peut voir les logs
create policy "Logs admin only" on public.pipeline_logs
  for select using (auth.role() = 'service_role');


-- ── 8. ACTIVER REALTIME SUR LES NOUVELLES TABLES ─────────────

alter publication supabase_realtime add table public.player_notes_history;
alter publication supabase_realtime add table public.match_results;
alter publication supabase_realtime add table public.journees;


-- ═══════════════════════════════════════════════════════════════
-- ✅ PHASE 3 SQL TERMINÉ
-- Tables journées · Notes historiques · Classement auto · Vues
-- ═══════════════════════════════════════════════════════════════
