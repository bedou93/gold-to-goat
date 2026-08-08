// ═══════════════════════════════════════════════════════════════
// gtg-supabase.js — Couche de connexion Supabase pour GTG
// ───────────────────────────────────────────────────────────────
// INSTRUCTIONS :
// 1. Va sur supabase.com → ton projet → Settings → API
// 2. Copie "Project URL" → colle dans SUPABASE_URL
// 3. Copie "anon public key" → colle dans SUPABASE_KEY
// 4. Inclus ce fichier dans tous tes HTML AVANT tout autre script
// ═══════════════════════════════════════════════════════════════

// ── CONFIGURATION ──────────────────────────────────────────────
const SUPABASE_URL = 'https://jajkpalrjujnptjrcqwx.supabase.co'
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImphamtwYWxyanVqbnB0anJjcXd4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzkyODk3MjIsImV4cCI6MjA5NDg2NTcyMn0.QVfY7pTZU0SSWZI_uX918E2ai_-FemGY_rGrRqS_i2g'

// ── INIT CLIENT ───────────────────────────────────────────────
// Supabase est chargé via CDN dans le HTML (voir plus bas)
// On initialise après que le DOM soit prêt
let supabase = null

function initSupabase() {
  if (window.supabase && !supabase) {
    supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_KEY)
    console.log('[GTG] ✅ Supabase connecté')
  }
}

// ═══════════════════════════════════════════════════════════════
// AUTH — Inscription & Connexion
// ═══════════════════════════════════════════════════════════════

const Auth = {

  // S'inscrire avec email + mot de passe
  async signup(email, password, pseudo) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { pseudo } }
    })
    if (error) throw error
    return data
  },

  // Se connecter
  async login(email, password) {
    const { data, error } = await supabase.auth.signInWithPassword({
      email, password
    })
    if (error) throw error
    GTG.currentUser = data.user
    GTG.currentSession = data.session
    await GTG.loadProfile()
    return data
  },

  // Se déconnecter
  async logout() {
    await supabase.auth.signOut()
    GTG.currentUser = null
    GTG.currentProfile = null
    GTG.currentTeam = null
  },

  // Récupérer la session active (au chargement de la page)
  async getSession() {
    const { data: { session } } = await supabase.auth.getSession()
    if (session) {
      GTG.currentUser = session.user
      GTG.currentSession = session
      await GTG.loadProfile()
    }
    return session
  },

  // Écouter les changements d'état auth
  onAuthChange(callback) {
    return supabase.auth.onAuthStateChange((event, session) => {
      callback(event, session)
    })
  }
}

// ═══════════════════════════════════════════════════════════════
// PROFILS
// ═══════════════════════════════════════════════════════════════

const Profiles = {

  async getById(userId) {
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', userId)
      .single()
    if (error) throw error
    return data
  },

  async update(userId, updates) {
    const { data, error } = await supabase
      .from('profiles')
      .update(updates)
      .eq('id', userId)
    if (error) throw error
    return data
  }
}

// ═══════════════════════════════════════════════════════════════
// LIGUES
// ═══════════════════════════════════════════════════════════════

const Leagues = {

  // Créer une nouvelle ligue
  async create({ nom, nb_joueurs, mode, budget_initial, nb_tours, description }) {
    const code = generateCode()
    const { data, error } = await supabase
      .from('leagues')
      .insert({
        nom,
        code,
        admin_id: GTG.currentUser.id,
        mode,
        nb_joueurs,
        budget_initial,
        nb_tours,
        description
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  // Rejoindre une ligue par code
  async join(code, teamData) {
    // 1. Trouver la ligue
    const { data: league, error: e1 } = await supabase
      .from('leagues')
      .select('*')
      .eq('code', code.toUpperCase())
      .single()
    if (e1) throw new Error('Code de ligue introuvable')

    // Vérifier si la ligue n'est pas pleine
    const { count } = await supabase
      .from('teams')
      .select('*', { count: 'exact' })
      .eq('league_id', league.id)
    if (count >= league.nb_joueurs) throw new Error('Cette ligue est complète')

    // 2. Créer l'équipe dans cette ligue
    const team = await Teams.create(league.id, teamData, league.budget_initial)
    return { league, team }
  },

  // Récupérer les ligues du coach connecté
  async getMyLeagues() {
    const { data, error } = await supabase
      .from('leagues')
      .select(`
        *,
        teams!inner(id, nom, coach_id, points, budget),
        teams_count:teams(count)
      `)
      .eq('teams.coach_id', GTG.currentUser.id)
      .order('created_at', { ascending: false })
    if (error) throw error
    return data
  },

  // Détail d'une ligue avec toutes ses équipes
  async getDetail(leagueId) {
    const { data, error } = await supabase
      .from('leagues')
      .select(`
        *,
        admin:profiles!admin_id(pseudo, email),
        teams(
          id, nom, couleur, budget, points, buts_pour, buts_contre,
          coach:profiles!coach_id(pseudo)
        )
      `)
      .eq('id', leagueId)
      .single()
    if (error) throw error
    return data
  },

  // Rechercher par code (avant de rejoindre)
  async findByCode(code) {
    const { data, error } = await supabase
      .from('leagues')
      .select(`
        *,
        teams(count)
      `)
      .eq('code', code.toUpperCase())
      .single()
    if (error) throw null
    return data
  },

  // Mettre à jour les horaires du mercato (admin seulement)
  async setMercatoSchedule(leagueId, schedule) {
    const { error } = await supabase
      .from('leagues')
      .update(schedule)
      .eq('id', leagueId)
      .eq('admin_id', GTG.currentUser.id)
    if (error) throw error
  }
}

// ═══════════════════════════════════════════════════════════════
// ÉQUIPES
// ═══════════════════════════════════════════════════════════════

const Teams = {

  async create(leagueId, { nom, couleur, stade }, budget) {
    const { data, error } = await supabase
      .from('teams')
      .insert({
        league_id: leagueId,
        coach_id: GTG.currentUser.id,
        nom,
        couleur: couleur || '#c8a020',
        stade,
        budget
      })
      .select()
      .single()
    if (error) throw error
    return data
  },

  async getMyTeam(leagueId) {
    const { data, error } = await supabase
      .from('teams')
      .select(`
        *,
        squads(
          *,
          player:players(*)
        )
      `)
      .eq('league_id', leagueId)
      .eq('coach_id', GTG.currentUser.id)
      .single()
    if (error) return null
    return data
  },

  async update(teamId, updates) {
    const { data, error } = await supabase
      .from('teams')
      .update(updates)
      .eq('id', teamId)
      .eq('coach_id', GTG.currentUser.id)
    if (error) throw error
    return data
  }
}

// ═══════════════════════════════════════════════════════════════
// JOUEURS (base Transfermarkt)
// ═══════════════════════════════════════════════════════════════

const Players = {

  async getAll({ poste, search, club, sortBy = 'cote_tm', sortDesc = true } = {}) {
    let query = supabase
      .from('players')
      .select('*')
      .eq('actif', true)

    if (poste) query = query.eq('poste', poste)
    if (club)  query = query.eq('club', club)
    if (search) query = query.ilike('nom', `%${search}%`)

    query = query.order(sortBy, { ascending: !sortDesc })

    const { data, error } = await query
    if (error) throw error
    return data
  },

  // Joueurs disponibles dans une ligue (non encore achetés)
  async getAvailableInLeague(leagueId) {
    // Récupérer les IDs déjà achetés dans cette ligue
    const { data: taken } = await supabase
      .from('squads')
      .select('player_id')
      .eq('league_id', leagueId)

    const takenIds = (taken || []).map(s => s.player_id)

    let query = supabase.from('players').select('*').eq('actif', true)
    if (takenIds.length > 0) {
      query = query.not('id', 'in', `(${takenIds.join(',')})`)
    }

    const { data, error } = await query.order('cote_tm', { ascending: false })
    if (error) throw error
    return data
  }
}

// ═══════════════════════════════════════════════════════════════
// ENCHÈRES
// ═══════════════════════════════════════════════════════════════

const Bids = {

  // Placer / modifier une enchère
  async placeBid(leagueId, playerId, montant, tour) {
    // Vérifier le budget
    const team = await Teams.getMyTeam(leagueId)
    if (!team) throw new Error('Équipe introuvable')

    // Calculer le total déjà engagé (hors ce joueur)
    const { data: existingBids } = await supabase
      .from('bids')
      .select('montant, player_id')
      .eq('league_id', leagueId)
      .eq('team_id', team.id)
      .eq('tour', tour)
      .neq('player_id', playerId)

    const engaged = (existingBids || []).reduce((s, b) => s + b.montant, 0)
    if (engaged + montant > team.budget) {
      throw new Error('Budget insuffisant')
    }

    // Upsert l'enchère (créer ou mettre à jour)
    const { data, error } = await supabase
      .from('bids')
      .upsert({
        league_id: leagueId,
        team_id: team.id,
        player_id: playerId,
        montant,
        tour,
        submitted: false
      }, { onConflict: 'league_id,team_id,player_id,tour' })
      .select()
      .single()

    if (error) throw error
    return data
  },

  // Soumettre toutes les enchères d'un tour (les verrouille)
  async submitRound(leagueId, tour) {
    const team = await Teams.getMyTeam(leagueId)
    if (!team) throw new Error('Équipe introuvable')

    const { error } = await supabase
      .from('bids')
      .update({ submitted: true })
      .eq('league_id', leagueId)
      .eq('team_id', team.id)
      .eq('tour', tour)

    if (error) throw error
    return true
  },

  // Récupérer mes enchères pour un tour
  async getMyBids(leagueId, tour) {
    const team = await Teams.getMyTeam(leagueId)
    if (!team) return []

    const { data, error } = await supabase
      .from('bids')
      .select('*, player:players(*)')
      .eq('league_id', leagueId)
      .eq('team_id', team.id)
      .eq('tour', tour)
      .order('created_at')

    if (error) throw error
    return data
  },

  // Récupérer les résultats (après résolution)
  async getResults(leagueId, tour) {
    const team = await Teams.getMyTeam(leagueId)
    if (!team) return []

    const { data, error } = await supabase
      .from('bids')
      .select('*, player:players(*)')
      .eq('league_id', leagueId)
      .eq('team_id', team.id)
      .eq('tour', tour)
      .neq('statut', 'en_attente')  // Seulement les résolues

    if (error) throw error
    return data
  },

  // Écouter les résultats en temps réel (Supabase Realtime)
  subscribeToResults(leagueId, tour, callback) {
    return supabase
      .channel(`bids-results-${leagueId}-${tour}`)
      .on('postgres_changes', {
        event: 'UPDATE',
        schema: 'public',
        table: 'bids',
        filter: `league_id=eq.${leagueId}`
      }, (payload) => {
        if (payload.new.statut !== 'en_attente') {
          callback(payload.new)
        }
      })
      .subscribe()
  }
}

// ═══════════════════════════════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════════════════════════════

const Notifications = {

  async getAll(limit = 20) {
    const { data, error } = await supabase
      .from('notifications')
      .select('*')
      .eq('user_id', GTG.currentUser.id)
      .order('created_at', { ascending: false })
      .limit(limit)
    if (error) throw error
    return data
  },

  async markRead(notifId) {
    await supabase
      .from('notifications')
      .update({ lue: true })
      .eq('id', notifId)
  },

  async markAllRead() {
    await supabase
      .from('notifications')
      .update({ lue: true })
      .eq('user_id', GTG.currentUser.id)
      .eq('lue', false)
  },

  // Écouter les nouvelles notifications en temps réel
  subscribe(callback) {
    return supabase
      .channel('notifications-' + GTG.currentUser.id)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'notifications',
        filter: `user_id=eq.${GTG.currentUser.id}`
      }, (payload) => callback(payload.new))
      .subscribe()
  }
}

// ═══════════════════════════════════════════════════════════════
// ÉTAT GLOBAL GTG
// ═══════════════════════════════════════════════════════════════

const GTG = {
  currentUser: null,
  currentSession: null,
  currentProfile: null,
  currentTeam: null,
  currentLeague: null,

  // Charger le profil du coach connecté
  async loadProfile() {
    if (!GTG.currentUser) return null
    try {
      GTG.currentProfile = await Profiles.getById(GTG.currentUser.id)
    } catch (e) {
      console.warn('[GTG] Profil non trouvé, sera créé automatiquement')
    }
    return GTG.currentProfile
  },

  // Charger les données d'une ligue
  async loadLeague(leagueId) {
    GTG.currentLeague = await Leagues.getDetail(leagueId)
    GTG.currentTeam = await Teams.getMyTeam(leagueId)
    return { league: GTG.currentLeague, team: GTG.currentTeam }
  },

  // Vérifier si l'utilisateur est connecté
  isLoggedIn() {
    return !!GTG.currentUser
  },

  // Forcer la connexion si pas connecté
  requireAuth(redirectUrl = 'gtg-auth.html') {
    if (!GTG.isLoggedIn()) {
      window.location.href = redirectUrl
      return false
    }
    return true
  },

  // Formater un montant (centimes → M€)
  formatBudget(centimes) {
    const millions = centimes / 1000000000 // On divise par 1 milliard car cotes en centimes × 1000
    if (millions >= 1000) return `${(millions/1000).toFixed(1)}Md€`
    if (millions >= 1)    return `${millions.toFixed(1)}M€`
    return `${(millions * 1000).toFixed(0)}k€`
  },

  // Générer un code de ligue unique
  generateCode() { return generateCode() }
}

// ─── Helpers ───────────────────────────────────────────────────

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let code = 'GTG-'
  for (let i = 0; i < 5; i++) code += chars[Math.floor(Math.random() * chars.length)]
  return code
}

// Exposer globalement
window.GTG = GTG
window.Auth = Auth
window.Leagues = Leagues
window.Teams = Teams
window.Players = Players
window.Bids = Bids
window.Notifications = Notifications
window.Profiles = Profiles

console.log('[GTG] 🚀 gtg-supabase.js chargé — configure SUPABASE_URL et SUPABASE_KEY')
