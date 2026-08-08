-- ═══════════════════════════════════════════════════════════════
-- GTG PHASE 4 — SQL Corrigé
-- ═══════════════════════════════════════════════════════════════

-- ── 1. TABLE : ÉTAT LIVE DES MATCHS ──────────────────────────
create table if not exists public.live_matches (
  id              uuid default uuid_generate_v4() primary key,
  fixture_id      bigint unique not null,
  league_id       uuid references public.leagues(id),
  home_team_api   text not null,
  away_team_api   text not null,
  home_score      int default 0,
  away_score      int default 0,
  minute          int default 0,
  statut          text default 'not_started'
                  check(statut in ('not_started','first_half','halftime','second_half','extra_time','finished')),
  started_at      timestamptz,
  updated_at      timestamptz default now()
);

alter table public.live_matches enable row level security;

create policy "Live matchs select" on public.live_matches
  for select using (true);

create policy "Live matchs insert" on public.live_matches
  for insert with check (auth.role() = 'service_role');

create policy "Live matchs update" on public.live_matches
  for update using (auth.role() = 'service_role');

create policy "Live matchs delete" on public.live_matches
  for delete using (auth.role() = 'service_role');

alter publication supabase_realtime add table public.live_matches;


-- ── 2. TABLE : NOTES LIVE JOUEURS ────────────────────────────
create table if not exists public.live_notes (
  id              uuid default uuid_generate_v4() primary key,
  player_id       uuid references public.players(id) on delete cascade not null,
  fixture_id      bigint references public.live_matches(fixture_id),
  note_live       numeric(3,1) not null,
  note_prev       numeric(3,1),
  minute          int default 0,
  buts_match      int default 0,
  passes_match    int default 0,
  carton_jaune    boolean default false,
  carton_rouge    boolean default false,
  est_titulaire   boolean default true,
  est_remplace    boolean default false,
  est_goat        boolean default false,
  updated_at      timestamptz default now(),
  unique(player_id, fixture_id)
);

alter table public.live_notes enable row level security;

create policy "Notes live select" on public.live_notes
  for select using (true);

create policy "Notes live insert" on public.live_notes
  for insert with check (auth.role() = 'service_role');

create policy "Notes live update" on public.live_notes
  for update using (auth.role() = 'service_role');

alter publication supabase_realtime add table public.live_notes;


-- ── 3. TABLE : ÉVÉNEMENTS LIVE ────────────────────────────────
create table if not exists public.live_events (
  id              uuid default uuid_generate_v4() primary key,
  fixture_id      bigint references public.live_matches(fixture_id),
  minute          int not null,
  type            text not null
                  check(type in ('but_reel','but_gtg','carton_jaune','carton_rouge',
                                 'remplacement','catenaccio','goat','mi_temps','fin_match')),
  player_id       uuid references public.players(id),
  player_nom      text,
  equipe          text,
  detail          jsonb,
  created_at      timestamptz default now()
);

alter table public.live_events enable row level security;

create policy "Events live select" on public.live_events
  for select using (true);

create policy "Events live insert" on public.live_events
  for insert with check (auth.role() = 'service_role');

alter publication supabase_realtime add table public.live_events;


-- ── 4. TABLE : SCORES GTG PROVISOIRES ────────────────────────
create table if not exists public.live_gtg_scores (
  id              uuid default uuid_generate_v4() primary key,
  match_id        uuid references public.matches(id),
  league_id       uuid references public.leagues(id),
  fixture_id      bigint,
  score_home_prov int default 0,
  score_away_prov int default 0,
  real_home       int default 0,
  real_away       int default 0,
  gtg_home        int default 0,
  gtg_away        int default 0,
  minute          int default 0,
  duels_detail    jsonb,
  updated_at      timestamptz default now(),
  unique(match_id)
);

alter table public.live_gtg_scores enable row level security;

create policy "Scores provisoires select" on public.live_gtg_scores
  for select using (true);

create policy "Scores provisoires insert" on public.live_gtg_scores
  for insert with check (auth.role() = 'service_role');

create policy "Scores provisoires update" on public.live_gtg_scores
  for update using (auth.role() = 'service_role');

alter publication supabase_realtime add table public.live_gtg_scores;


-- ── 5. TABLE : PUSH SUBSCRIPTIONS ────────────────────────────
create table if not exists public.push_subscriptions (
  id              uuid default uuid_generate_v4() primary key,
  user_id         uuid references public.profiles(id) on delete cascade not null unique,
  onesignal_id    text,
  platform        text check(platform in ('web','ios','android')),
  notif_buts      boolean default true,
  notif_cartons   boolean default true,
  notif_resultats boolean default true,
  notif_mercato   boolean default true,
  created_at      timestamptz default now(),
  updated_at      timestamptz default now()
);

alter table public.push_subscriptions enable row level security;

create policy "Push sub select" on public.push_subscriptions
  for select using (auth.uid() = user_id);

create policy "Push sub insert" on public.push_subscriptions
  for insert with check (auth.uid() = user_id);

create policy "Push sub update" on public.push_subscriptions
  for update using (auth.uid() = user_id);

create policy "Push sub delete" on public.push_subscriptions
  for delete using (auth.uid() = user_id);


-- ── 6. TABLE : MAPPING JOUEURS API ────────────────────────────
create table if not exists public.player_api_mapping (
  id              uuid default uuid_generate_v4() primary key,
  player_id       uuid references public.players(id) on delete cascade unique,
  api_football_id bigint unique,
  api_name        text,
  verified        boolean default false,
  created_at      timestamptz default now()
);

alter table public.player_api_mapping enable row level security;

create policy "Mapping select" on public.player_api_mapping
  for select using (true);

create policy "Mapping insert" on public.player_api_mapping
  for insert with check (auth.role() = 'service_role');

create policy "Mapping update" on public.player_api_mapping
  for update using (auth.role() = 'service_role');


-- ── 7. VUE : TABLEAU DE BORD LIVE ────────────────────────────
create or replace view public.live_dashboard as
select
  ln.player_id,
  p.nom           as player_nom,
  p.club,
  p.poste,
  ln.note_live,
  ln.note_prev,
  ln.note_live - ln.note_prev as delta_note,
  ln.minute,
  ln.buts_match,
  ln.passes_match,
  ln.carton_jaune,
  ln.carton_rouge,
  ln.est_goat,
  ln.fixture_id,
  lm.home_team_api,
  lm.away_team_api,
  lm.statut       as match_statut
from public.live_notes ln
join public.players p      on p.id  = ln.player_id
join public.live_matches lm on lm.fixture_id = ln.fixture_id
where lm.statut not in ('finished','not_started');


-- ── 8. FONCTION : UPSERT NOTE LIVE ────────────────────────────
create or replace function public.upsert_live_note(
  p_player_id    uuid,
  p_fixture_id   bigint,
  p_note         numeric,
  p_minute       int,
  p_buts         int     default 0,
  p_passes       int     default 0,
  p_carton_j     boolean default false,
  p_carton_r     boolean default false
)
returns void as $$
begin
  insert into public.live_notes(
    player_id, fixture_id, note_live, note_prev, minute,
    buts_match, passes_match, carton_jaune, carton_rouge, updated_at
  )
  values(
    p_player_id, p_fixture_id, p_note,
    (select note_actuelle from public.players where id = p_player_id),
    p_minute, p_buts, p_passes, p_carton_j, p_carton_r, now()
  )
  on conflict(player_id, fixture_id) do update set
    note_live    = p_note,
    minute       = p_minute,
    buts_match   = p_buts,
    passes_match = p_passes,
    carton_jaune = p_carton_j,
    carton_rouge = p_carton_r,
    updated_at   = now();
end;
$$ language plpgsql security definer;


-- ── 9. INDEXES ────────────────────────────────────────────────
create index if not exists idx_live_notes_fixture   on public.live_notes(fixture_id);
create index if not exists idx_live_notes_player    on public.live_notes(player_id);
create index if not exists idx_live_events_fixture  on public.live_events(fixture_id);
create index if not exists idx_live_events_minute   on public.live_events(minute);
create index if not exists idx_api_mapping_api_id   on public.player_api_mapping(api_football_id);


-- ═══════════════════════════════════════════════════════════════
-- ✅ PHASE 4 SQL CORRIGÉ ET TERMINÉ
-- ═══════════════════════════════════════════════════════════════
