-- ═══════════════════════════════════════════════════════════════
-- GTG PHASE 6 — Budgets d'équipes MPG prédéfinis par l'admin
-- ───────────────────────────────────────────────────────────────
-- Quand un admin crée une ligue en cochant "Reprendre les effectifs MPG",
-- il saisit le nom + budget restant de chaque équipe AVANT que les coachs
-- ne rejoignent. Chaque coach "réclame" ensuite une de ces équipes en
-- rejoignant la ligue, ce qui crée sa vraie ligne dans `teams` avec le
-- bon budget de départ (au lieu du budget par défaut de la ligue).
-- ═══════════════════════════════════════════════════════════════

create table if not exists public.mpg_planned_teams (
  id                  uuid default uuid_generate_v4() primary key,
  league_id           uuid references public.leagues(id) on delete cascade not null,
  nom                 text not null,
  budget              bigint not null,        -- même échelle que teams.budget (1 M€ = 1e9)
  claimed_by_team_id  uuid references public.teams(id),
  created_at          timestamptz default now(),
  unique(league_id, nom)
);

alter table public.mpg_planned_teams enable row level security;

-- Tout le monde peut voir les équipes prédéfinies d'une ligue (pour les choisir en rejoignant)
create policy "Equipes MPG visibles par tous" on public.mpg_planned_teams
  for select using (true);

-- Seul l'admin de la ligue peut créer/supprimer les emplacements d'équipes
create policy "Admin cree les equipes MPG" on public.mpg_planned_teams
  for insert with check (
    auth.uid() = (select admin_id from public.leagues where id = league_id)
  );

create policy "Admin supprime les equipes MPG" on public.mpg_planned_teams
  for delete using (
    auth.uid() = (select admin_id from public.leagues where id = league_id)
  );

-- N'importe quel coach peut "réclamer" une équipe non encore prise,
-- à condition de se l'attribuer à lui-même (son propre team_id)
create policy "Coach reclame une equipe MPG" on public.mpg_planned_teams
  for update
  using (claimed_by_team_id is null)
  with check (
    claimed_by_team_id is not null
    and auth.uid() = (select coach_id from public.teams where id = claimed_by_team_id)
  );

create index if not exists idx_mpg_planned_league on public.mpg_planned_teams(league_id);

-- ═══════════════════════════════════════════════════════════════
-- ✅ PHASE 6 SQL TERMINÉ
-- ═══════════════════════════════════════════════════════════════
