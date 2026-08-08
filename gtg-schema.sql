-- ═══════════════════════════════════════════════════════════════
-- GOLD TO GOAT — Supabase Schema v1.0
-- ───────────────────────────────────────────────────────────────
-- INSTRUCTIONS :
-- 1. Va sur supabase.com → ton projet → SQL Editor
-- 2. Copie-colle TOUT ce fichier
-- 3. Clique sur "Run"
-- C'est tout. Toutes les tables seront créées automatiquement.
-- ═══════════════════════════════════════════════════════════════

-- Active l'extension UUID (nécessaire pour les IDs auto)
create extension if not exists "uuid-ossp";

-- ───────────────────────────────────────────────────────────────
-- TABLE 1 : PROFILS COACHES
-- Créé automatiquement quand un utilisateur s'inscrit
-- ───────────────────────────────────────────────────────────────
create table public.profiles (
  id          uuid references auth.users(id) on delete cascade primary key,
  pseudo      text not null unique,
  email       text not null,
  avatar_url  text,
  created_at  timestamptz default now()
);

-- Sécurité : chaque coach ne voit que son propre profil
alter table public.profiles enable row level security;

create policy "Profil visible par tous" on public.profiles
  for select using (true);

create policy "Coach modifie son propre profil" on public.profiles
  for update using (auth.uid() = id);

create policy "Création automatique du profil" on public.profiles
  for insert with check (auth.uid() = id);

-- Trigger : crée automatiquement un profil quand un user s'inscrit
create or replace function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, pseudo, email)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'pseudo', split_part(new.email, '@', 1)),
    new.email
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();


-- ───────────────────────────────────────────────────────────────
-- TABLE 2 : LIGUES
-- Une ligue = un mini-championnat GTG entre amis
-- ───────────────────────────────────────────────────────────────
create table public.leagues (
  id              uuid default uuid_generate_v4() primary key,
  nom             text not null,
  code            text not null unique,           -- ex: GTG-4X8K2
  admin_id        uuid references public.profiles(id) not null,
  mode            text default 'amical'           -- 'amical' | 'professionnel'
                  check (mode in ('amical','professionnel')),
  nb_joueurs      int default 8
                  check (nb_joueurs in (4,6,8,10,12)),
  budget_initial  bigint default 350000000,       -- 350M€ en centimes
  nb_tours        int default 3
                  check (nb_tours in (1,2,3)),
  statut          text default 'recrutement'      -- 'recrutement'|'mercato'|'saison'|'terminee'
                  check (statut in ('recrutement','mercato','saison','terminee')),
  saison          text default '2025-26',
  description     text,
  -- Horaires mercato (définis par l'admin)
  mercato_tour1_open   timestamptz,
  mercato_tour1_close  timestamptz,
  mercato_tour2_open   timestamptz,
  mercato_tour2_close  timestamptz,
  mercato_tour3_open   timestamptz,
  mercato_tour3_close  timestamptz,
  created_at      timestamptz default now()
);

alter table public.leagues enable row level security;

create policy "Ligue visible par tous" on public.leagues
  for select using (true);

create policy "Admin cree sa ligue" on public.leagues
  for insert with check (auth.uid() = admin_id);

create policy "Admin modifie sa ligue" on public.leagues
  for update using (auth.uid() = admin_id);


-- ───────────────────────────────────────────────────────────────
-- TABLE 3 : ÉQUIPES
-- Une équipe = un coach dans une ligue
-- ───────────────────────────────────────────────────────────────
create table public.teams (
  id          uuid default uuid_generate_v4() primary key,
  league_id   uuid references public.leagues(id) on delete cascade not null,
  coach_id    uuid references public.profiles(id) on delete cascade not null,
  nom         text not null,
  couleur     text default '#c8a020',
  stade       text,
  budget      bigint default 350000000,           -- budget restant en centimes
  points      int default 0,
  buts_pour   int default 0,
  buts_contre int default 0,
  created_at  timestamptz default now(),
  unique(league_id, coach_id)                     -- 1 équipe par coach par ligue
);

alter table public.teams enable row level security;

create policy "Equipe visible par membres de la ligue" on public.teams
  for select using (true);

create policy "Coach cree son equipe" on public.teams
  for insert with check (auth.uid() = coach_id);

create policy "Coach modifie son equipe" on public.teams
  for update using (auth.uid() = coach_id);


-- ───────────────────────────────────────────────────────────────
-- TABLE 4 : JOUEURS (base Transfermarkt)
-- Tous les joueurs de Ligue 1 avec leurs cotes
-- ───────────────────────────────────────────────────────────────
create table public.players (
  id          uuid default uuid_generate_v4() primary key,
  nom         text not null,
  club        text not null,
  poste       text not null check (poste in ('GK','DEF','MID','ATT')),
  nationalite text,
  age         int,
  cote_tm     bigint not null,                    -- cote Transfermarkt en centimes (ex: 110M = 11000000000)
  cote_prev   bigint,                             -- cote précédente pour évolution
  note_actuelle numeric(3,1) default 6.0,         -- note après dernière journée L1
  note_moyenne  numeric(3,1) default 6.0,         -- moyenne sur la saison
  buts_saison   int default 0,
  passes_saison int default 0,
  actif       boolean default true,               -- false si blessé/parti
  updated_at  timestamptz default now()
);

alter table public.players enable row level security;
create policy "Joueurs visibles par tous" on public.players
  for select using (true);
-- Seul le service backend peut modifier les joueurs (pas les utilisateurs)
create policy "Service backend modifie joueurs" on public.players
  for all using (auth.role() = 'service_role');


-- ───────────────────────────────────────────────────────────────
-- TABLE 5 : EFFECTIFS (joueurs achetés par chaque équipe)
-- ───────────────────────────────────────────────────────────────
create table public.squads (
  id          uuid default uuid_generate_v4() primary key,
  team_id     uuid references public.teams(id) on delete cascade not null,
  player_id   uuid references public.players(id) not null,
  league_id   uuid references public.leagues(id) not null,  -- pour contrainte unicité
  prix_achat  bigint not null,                    -- prix payé aux enchères
  titulaire   boolean default true,
  ordre_remplacant int,                           -- 1 à 6 pour l'ordre des remplaçants
  created_at  timestamptz default now(),
  unique(player_id, league_id)                    -- UN joueur = UNE équipe par ligue
);

alter table public.squads enable row level security;

create policy "Effectif visible par tous" on public.squads
  for select using (true);

create policy "Coach gere son effectif" on public.squads
  for all using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );


-- ───────────────────────────────────────────────────────────────
-- TABLE 6 : ENCHÈRES
-- Chaque mise d'un coach sur un joueur pendant le mercato
-- ───────────────────────────────────────────────────────────────
create table public.bids (
  id          uuid default uuid_generate_v4() primary key,
  league_id   uuid references public.leagues(id) on delete cascade not null,
  team_id     uuid references public.teams(id) on delete cascade not null,
  player_id   uuid references public.players(id) not null,
  montant     bigint not null,                    -- montant misé en centimes
  tour        int not null check (tour in (1,2,3)),
  statut      text default 'en_attente'
              check (statut in ('en_attente','gagnant','perdant','egalite_gagnant','egalite_perdant')),
  submitted   boolean default false,              -- coach a validé ses enchères
  created_at  timestamptz default now(),
  updated_at  timestamptz default now(),
  unique(league_id, team_id, player_id, tour)     -- 1 enchère par joueur par tour par équipe
);

alter table public.bids enable row level security;

-- UN COACH NE VOIT PAS LES ENCHÈRES DES AUTRES (enchères cachées !)
create policy "Coach voit UNIQUEMENT ses propres encheres" on public.bids
  for select using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );

create policy "Coach cree ses encheres" on public.bids
  for insert with check (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );

create policy "Coach modifie ses encheres" on public.bids
  for update using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
  );

-- APRÈS RÉSOLUTION : tout le monde peut voir les résultats
create policy "Resultats visibles apres resolution" on public.bids
  for select using (statut != 'en_attente');


-- ───────────────────────────────────────────────────────────────
-- TABLE 7 : MATCHS / CONFRONTATIONS
-- Le calendrier des confrontations GTG
-- ───────────────────────────────────────────────────────────────
create table public.matches (
  id              uuid default uuid_generate_v4() primary key,
  league_id       uuid references public.leagues(id) on delete cascade not null,
  home_team_id    uuid references public.teams(id) not null,
  away_team_id    uuid references public.teams(id) not null,
  journee         int not null,
  -- Scores finaux
  score_home      int default 0,
  score_away      int default 0,
  -- Détail buts
  buts_reels_home int default 0,
  buts_reels_away int default 0,
  buts_gtg_home   int default 0,
  buts_gtg_away   int default 0,
  -- Infos
  statut          text default 'a_venir'
                  check (statut in ('a_venir','en_cours','termine')),
  date_match      timestamptz,
  created_at      timestamptz default now()
);

alter table public.matches enable row level security;
create policy "Matchs visibles par tous" on public.matches
  for select using (true);


-- ───────────────────────────────────────────────────────────────
-- TABLE 8 : COMPOSITIONS
-- La compo choisie par chaque coach pour chaque journée
-- ───────────────────────────────────────────────────────────────
create table public.lineups (
  id          uuid default uuid_generate_v4() primary key,
  match_id    uuid references public.matches(id) on delete cascade not null,
  team_id     uuid references public.teams(id) not null,
  formation   text default '4-3-3',
  -- Titulaires (IDs des joueurs sélectionnés)
  gk          uuid references public.players(id),
  def1        uuid references public.players(id),
  def2        uuid references public.players(id),
  def3        uuid references public.players(id),
  def4        uuid references public.players(id),
  def5        uuid references public.players(id),
  mid1        uuid references public.players(id),
  mid2        uuid references public.players(id),
  mid3        uuid references public.players(id),
  mid4        uuid references public.players(id),
  mid5        uuid references public.players(id),
  att1        uuid references public.players(id),
  att2        uuid references public.players(id),
  att3        uuid references public.players(id),
  -- Remplaçants (ordre priorité)
  sub1        uuid references public.players(id),
  sub2        uuid references public.players(id),
  sub3        uuid references public.players(id),
  sub4        uuid references public.players(id),
  sub5        uuid references public.players(id),
  sub6        uuid references public.players(id),
  locked      boolean default false,              -- true = plus modifiable (match commencé)
  created_at  timestamptz default now(),
  unique(match_id, team_id)
);

alter table public.lineups enable row level security;

create policy "Compo visible par tous apres match" on public.lineups
  for select using (true);

create policy "Coach modifie sa compo" on public.lineups
  for all using (
    auth.uid() = (select coach_id from public.teams where id = team_id)
    and locked = false
  );


-- ───────────────────────────────────────────────────────────────
-- TABLE 9 : ÉVÉNEMENTS DE MATCH
-- Chaque but, carton, remplacement enregistré
-- ───────────────────────────────────────────────────────────────
create table public.match_events (
  id          uuid default uuid_generate_v4() primary key,
  match_id    uuid references public.matches(id) on delete cascade not null,
  minute      int not null,
  type        text not null
              check (type in ('but_reel','but_gtg','carton_jaune','carton_rouge','remplacement','catenaccio','goat')),
  team_id     uuid references public.teams(id),
  player_id   uuid references public.players(id),
  detail      jsonb,                              -- données supplémentaires (duels, etc.)
  created_at  timestamptz default now()
);

alter table public.match_events enable row level security;
create policy "Evenements visibles par tous" on public.match_events
  for select using (true);


-- ───────────────────────────────────────────────────────────────
-- TABLE 10 : NOTIFICATIONS
-- ───────────────────────────────────────────────────────────────
create table public.notifications (
  id          uuid default uuid_generate_v4() primary key,
  user_id     uuid references public.profiles(id) on delete cascade not null,
  type        text not null,                      -- 'enchere_resultat'|'match_resultat'|'mercato_ouvert'|etc.
  titre       text not null,
  message     text not null,
  lue         boolean default false,
  data        jsonb,                              -- données contextuelles
  created_at  timestamptz default now()
);

alter table public.notifications enable row level security;

create policy "User voit ses notifs" on public.notifications
  for select using (auth.uid() = user_id);

create policy "User marque notif lue" on public.notifications
  for update using (auth.uid() = user_id);


-- ───────────────────────────────────────────────────────────────
-- FONCTION : Résolution automatique des enchères
-- Appelée par le backend quand un tour se ferme
-- ───────────────────────────────────────────────────────────────
create or replace function public.resoudre_encheres(
  p_league_id uuid,
  p_tour      int
)
returns void as $$
declare
  player_rec record;
  winner_bid record;
  bid_rec    record;
begin
  -- Pour chaque joueur ayant reçu au moins 1 enchère dans ce tour
  for player_rec in
    select distinct player_id
    from public.bids
    where league_id = p_league_id
      and tour = p_tour
      and submitted = true
  loop
    -- Trouver l'enchère gagnante (max montant, puis plus ancien timestamp)
    select * into winner_bid
    from public.bids
    where league_id = p_league_id
      and tour = p_tour
      and player_id = player_rec.player_id
      and submitted = true
    order by montant desc, created_at asc
    limit 1;

    -- Marquer toutes les enchères pour ce joueur
    for bid_rec in
      select * from public.bids
      where league_id = p_league_id
        and tour = p_tour
        and player_id = player_rec.player_id
        and submitted = true
    loop
      if bid_rec.id = winner_bid.id then
        -- Gagnant → ajouter le joueur à son effectif
        update public.bids set statut = 'gagnant' where id = bid_rec.id;

        insert into public.squads (team_id, player_id, league_id, prix_achat)
        values (bid_rec.team_id, bid_rec.player_id, p_league_id, bid_rec.montant)
        on conflict (player_id, league_id) do nothing;

        -- Déduire le montant du budget de l'équipe
        update public.teams
        set budget = budget - bid_rec.montant
        where id = bid_rec.team_id;

        -- Notifier le gagnant
        insert into public.notifications (user_id, type, titre, message, data)
        select coach_id, 'enchere_gagnee',
          '🏆 Joueur obtenu !',
          'Tu as remporté l''enchère pour ce joueur.',
          jsonb_build_object('player_id', bid_rec.player_id, 'montant', bid_rec.montant)
        from public.teams where id = bid_rec.team_id;

      else
        -- Perdant → notifier
        update public.bids set statut = 'perdant' where id = bid_rec.id;

        insert into public.notifications (user_id, type, titre, message, data)
        select coach_id, 'enchere_perdue',
          '❌ Enchère perdue',
          'Un autre coach a surenchéri. Disponible au tour suivant.',
          jsonb_build_object('player_id', bid_rec.player_id, 'gagnant_montant', winner_bid.montant)
        from public.teams where id = bid_rec.team_id;
      end if;
    end loop;
  end loop;
end;
$$ language plpgsql security definer;


-- ───────────────────────────────────────────────────────────────
-- DONNÉES DE BASE : Insérer les joueurs Ligue 1
-- (cotes en centimes : 110M€ = 11000000000)
-- ───────────────────────────────────────────────────────────────
insert into public.players (nom, club, poste, nationalite, age, cote_tm, cote_prev, note_actuelle, note_moyenne) values
-- PSG
('Vitinha',          'PSG', 'MID', '🇵🇹', 26, 11000000000, 9000000000,  8.2, 7.8),
('João Neves',       'PSG', 'MID', '🇵🇹', 21, 11000000000, 9000000000,  8.5, 8.0),
('O. Dembélé',       'PSG', 'ATT', '🇫🇷', 28, 10000000000, 7500000000,  8.8, 7.9),
('D. Doué',          'PSG', 'MID', '🇫🇷', 20,  9000000000, 6000000000,  7.5, 7.2),
('Kvaratskhelia',    'PSG', 'ATT', '🇬🇪', 25,  9000000000, 9000000000,  9.2, 8.4),
('A. Hakimi',        'PSG', 'DEF', '🇲🇦', 27,  8000000000, 6500000000,  7.5, 7.1),
('Nuno Mendes',      'PSG', 'DEF', '🇵🇹', 23,  7500000000, 6500000000,  7.8, 7.3),
('B. Barcola',       'PSG', 'ATT', '🇫🇷', 22,  7000000000, 7000000000,  7.5, 7.2),
('W. Pacho',         'PSG', 'DEF', '🇪🇨', 24,  7000000000, 6500000000,  7.0, 6.8),
('W. Zaïre-Emery',   'PSG', 'MID', '🇫🇷', 20,  5000000000, 5000000000,  7.0, 6.9),
('I. Zabarnyi',      'PSG', 'DEF', '🇺🇦', 23,  5500000000, 5000000000,  7.2, 6.9),
('G. Ramos',         'PSG', 'ATT', '🇵🇹', 24,  4500000000, 4000000000,  6.8, 6.5),
('L. Chevalier',     'PSG', 'GK',  '🇫🇷', 24,  4000000000, 3000000000,  7.2, 6.9),
('Fabián Ruiz',      'PSG', 'MID', '🇪🇸', 30,  3000000000, 3200000000,  6.5, 6.4),
('Lee Kang-In',      'PSG', 'MID', '🇰🇷', 25,  2800000000, 2500000000,  6.2, 6.2),
('M. Safonov',       'PSG', 'GK',  '🇷🇺', 27,  1800000000, 1800000000,  6.5, 6.3),
('Marquinhos',       'PSG', 'DEF', '🇧🇷', 31,  2200000000, 2500000000,  7.0, 6.8),
-- Monaco
('M. Akliouche',     'Monaco', 'ATT', '🇫🇷', 22, 4500000000, 4000000000, 7.8, 7.4),
('F. Balogun',       'Monaco', 'ATT', '🇺🇸', 24, 2200000000, 2000000000, 7.2, 6.9),
('L. Camara',        'Monaco', 'MID', '🇬🇳', 22, 2500000000, 2000000000, 7.0, 6.8),
('S. Adingra',       'Monaco', 'ATT', '🇨🇮', 23, 2000000000, 1800000000, 6.8, 6.5),
('A. Nübel',         'Monaco', 'GK',  '🇩🇪', 29, 2000000000, 1800000000, 6.5, 6.4),
('E. Ben Seghir',    'Monaco', 'ATT', '🇲🇦', 20, 3500000000, 3000000000, 7.5, 7.1),
('J. Teze',          'Monaco', 'DEF', '🇫🇷', 26, 1800000000, 1600000000, 6.8, 6.5),
('Caio Henrique',    'Monaco', 'DEF', '🇧🇷', 27, 1800000000, 1800000000, 6.5, 6.3),
-- Marseille
('M. Greenwood',     'OM', 'ATT', '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 24, 5000000000, 4000000000, 8.2, 7.6),
('A. Vermeeren',     'OM', 'MID', '🇧🇪', 20, 3000000000, 2500000000, 7.2, 6.9),
('V. Carboni',       'OM', 'MID', '🇮🇹', 20, 2200000000, 1800000000, 7.0, 6.7),
('Igor Paixão',      'OM', 'ATT', '🇧🇷', 25, 2500000000, 2000000000, 7.5, 7.1),
('B. Pavard',        'OM', 'DEF', '🇫🇷', 29, 2800000000, 3000000000, 7.0, 6.8),
('T. Weah',          'OM', 'DEF', '🇺🇸', 25, 1800000000, 1800000000, 6.5, 6.3),
('Rabiot',           'OM', 'MID', '🇫🇷', 30, 1200000000, 1500000000, 6.2, 6.1),
-- Lille
('A. Bouaddi',       'LOSC', 'MID', '🇫🇷', 18, 4000000000, 3000000000, 7.8, 7.2),
('B. Diakité',       'LOSC', 'DEF', '🇫🇷', 24, 2500000000, 1800000000, 7.0, 6.7),
('N. Mukau',         'LOSC', 'MID', '🇫🇷', 19, 1200000000,  400000000, 7.2, 6.8),
('A. Gomes',         'LOSC', 'MID', '🏴󠁧󠁢󠁥󠁮󠁧󠁿', 24, 2000000000, 2500000000, 6.5, 6.4),
('H. Haraldsson',    'LOSC', 'MID', '🇮🇸', 24, 1500000000,  900000000, 7.0, 6.6),
-- Rennes
('A. Gouiri',        'Rennes', 'ATT', '🇫🇷', 25, 2200000000, 2000000000, 7.1, 6.9),
('A. Truffert',      'Rennes', 'DEF', '🇫🇷', 24, 1500000000, 1200000000, 7.0, 6.7),
-- Lens
('K. Danso',         'Lens', 'DEF', '🇦🇹', 26, 2500000000, 2200000000, 7.0, 6.8),
('B. Mvogo',         'Lens', 'GK',  '🇨🇭', 30,  800000000,  800000000, 7.0, 6.7),
('L. Koleosho',      'Lens', 'ATT', '🇺🇸', 21, 1500000000, 1200000000, 7.2, 6.8),
-- Strasbourg
('L. Šeško',         'Strasbourg', 'ATT', '🇸🇮', 22, 3000000000, 2200000000, 7.5, 7.0),
('E. Emegha',        'Strasbourg', 'ATT', '🇳🇱', 23, 2000000000, 1500000000, 7.0, 6.7),
('M. Sarr',          'Strasbourg', 'DEF', '🇸🇳', 24, 1500000000,  800000000, 6.8, 6.5),
-- Nice
('M. Biereth',       'Nice', 'ATT', '🇩🇰', 22, 2500000000, 1300000000, 7.5, 7.0),
('J-C. Todibo',      'Nice', 'DEF', '🇫🇷', 26, 2800000000, 2500000000, 7.0, 6.8),
('G. Laborde',       'Nice', 'ATT', '🇫🇷', 31,  800000000, 1000000000, 6.5, 6.3),
-- OL
('A. Lacazette',     'OL', 'ATT', '🇫🇷', 34,  500000000,  800000000, 6.8, 6.5),
('S. Fofana',        'OL', 'MID', '🇨🇮', 29, 1500000000, 1200000000, 7.0, 6.7),
('M. Almada',        'OL', 'MID', '🇦🇷', 24, 2000000000, 1800000000, 7.2, 6.9),
-- Toulouse
('G. Dallinga',      'Toulouse', 'ATT', '🇳🇱', 23, 1400000000, 1200000000, 7.0, 6.7),
-- Nantes
('M. Zézé',          'Nantes', 'ATT', '🇫🇷', 21, 1000000000,  500000000, 6.8, 6.5),
-- Brest
('R. Del Castillo',  'Brest', 'ATT', '🇫🇷', 26, 1200000000, 1000000000, 7.0, 6.7),
-- Auxerre
('J-P. Mateta',      'Auxerre', 'ATT', '🇫🇷', 28, 1200000000, 1000000000, 7.0, 6.7),
-- Angers
('P. Peter',         'Angers', 'ATT', '🇸🇮', 23,  800000000,  500000000, 7.0, 6.6);


-- ───────────────────────────────────────────────────────────────
-- INDEX (performance)
-- ───────────────────────────────────────────────────────────────
create index idx_teams_league    on public.teams(league_id);
create index idx_squads_team     on public.squads(team_id);
create index idx_squads_league   on public.squads(league_id);
create index idx_bids_league     on public.bids(league_id);
create index idx_bids_team       on public.bids(team_id);
create index idx_bids_player     on public.bids(player_id);
create index idx_matches_league  on public.matches(league_id);
create index idx_notifs_user     on public.notifications(user_id);
create index idx_players_club    on public.players(club);
create index idx_players_poste   on public.players(poste);


-- ═══════════════════════════════════════════════════════════════
-- ✅ SCHEMA TERMINÉ
-- Toutes les tables sont créées et sécurisées.
-- Prochaine étape : coller les clés Supabase dans gtg-config.js
-- ═══════════════════════════════════════════════════════════════
