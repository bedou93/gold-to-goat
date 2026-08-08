// ═══════════════════════════════════════════════════════════════
// netlify/functions/mpg-import.js
// ───────────────────────────────────────────────────────────────
// Reçoit une capture d'écran d'équipe MPG (base64), demande à Claude
// d'en extraire la liste des joueurs (nom, poste, valeur d'achat),
// et renvoie un JSON strict au front-end pour validation manuelle.
//
// Variable d'environnement requise (à définir dans Netlify, PAS ici) :
//   ANTHROPIC_API_KEY
// ═══════════════════════════════════════════════════════════════

const ANTHROPIC_API_URL = 'https://api.anthropic.com/v1/messages'
const MODEL = 'claude-sonnet-5'
const MAX_IMAGE_BYTES = 8 * 1024 * 1024 // 8 Mo, marge sous la limite Anthropic (base64 gonfle ~33%)

const SYSTEM_PROMPT = `Tu analyses une capture d'écran de l'application MPG (Mon Petit Gazon) montrant la liste des joueurs d'une équipe ("LES EFFECTIFS DE LA LIGUE" ou écran d'effectif équivalent).

L'écran affiche un tableau avec ces colonnes, dans cet ordre : Joueur (nom, avec le club en petit texte gris juste en dessous), Poste, Achat, Cote.

Pour CHAQUE ligne de joueur visible, extrait :
- "nom" : le nom du joueur tel qu'affiché (garde les accents, corrige uniquement les erreurs de lecture évidentes)
- "club" : le nom du club affiché en petit sous le nom du joueur (ex: "Lens", "Marseille", "Paris", "Lille"). Si illisible, mets null.
- "poste" : convertis le code de poste MPG vers l'un de "GK", "DEF", "MID", "ATT" selon cette correspondance :
    - "G" → "GK"
    - "DC", "DL", "D" → "DEF"
    - "MD", "MO", "M" → "MID"
    - "A", "BU" → "ATT"
  Si le code ne correspond à rien de connu, déduis le poste le plus probable de sa position dans le tableau (gardiens en haut, puis défenseurs, milieux, attaquants en bas).
- "valeur" : prends UNIQUEMENT la valeur de la colonne "Achat" (le prix payé par le coach), PAS la colonne "Cote" (valeur actuelle du marché). C'est un nombre (ex: 23, 46.5). Si la colonne "Achat" est absente ou vide pour ce joueur, mets null — ne prends jamais "Cote" à la place.

Réponds UNIQUEMENT avec un JSON strict, sans texte avant ni après, sans balises markdown, au format exact :
{"players":[{"nom":"...","club":"...","poste":"GK","valeur":23}, ...]}

Si l'image ne semble pas être une capture d'effectif MPG ou si aucun joueur n'est identifiable, réponds avec {"players":[],"error":"raison courte"}.`

exports.handler = async (event) => {
  const headers = {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  }

  if (event.httpMethod === 'OPTIONS') {
    return { statusCode: 204, headers, body: '' }
  }

  if (event.httpMethod !== 'POST') {
    return { statusCode: 405, headers, body: JSON.stringify({ error: 'Méthode non autorisée' }) }
  }

  const apiKey = process.env.ANTHROPIC_API_KEY
  if (!apiKey) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'ANTHROPIC_API_KEY non configurée côté serveur (Netlify → Site settings → Environment variables).' }) }
  }

  let payload
  try {
    payload = JSON.parse(event.body || '{}')
  } catch {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Corps de requête invalide (JSON attendu).' }) }
  }

  const { image_base64, media_type } = payload
  const allowedTypes = ['image/png', 'image/jpeg', 'image/webp']

  if (!image_base64 || typeof image_base64 !== 'string') {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Image manquante (image_base64).' }) }
  }
  if (!allowedTypes.includes(media_type)) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Format image non supporté (png, jpeg ou webp uniquement).' }) }
  }
  if (image_base64.length > MAX_IMAGE_BYTES) {
    return { statusCode: 400, headers, body: JSON.stringify({ error: 'Image trop volumineuse (8 Mo max).' }) }
  }

  try {
    const resp = await fetch(ANTHROPIC_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 2000,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: 'user',
            content: [
              { type: 'image', source: { type: 'base64', media_type, data: image_base64 } },
              { type: 'text', text: 'Analyse cette capture MPG et renvoie le JSON demandé.' },
            ],
          },
        ],
      }),
    })

    if (!resp.ok) {
      const errText = await resp.text().catch(() => '')
      return { statusCode: 502, headers, body: JSON.stringify({ error: `Erreur API Claude (${resp.status}) : ${errText.slice(0, 300)}` }) }
    }

    const data = await resp.json()
    const textBlock = (data.content || []).find(b => b.type === 'text')
    const raw = textBlock?.text || ''

    let parsed
    try {
      const jsonStr = raw.trim().replace(/^```json\s*|\s*```$/g, '')
      parsed = JSON.parse(jsonStr)
    } catch {
      return { statusCode: 502, headers, body: JSON.stringify({ error: 'Réponse de Claude illisible (pas du JSON valide).', raw: raw.slice(0, 500) }) }
    }

    const players = Array.isArray(parsed.players) ? parsed.players
      .filter(p => p && typeof p.nom === 'string' && p.nom.trim())
      .map(p => ({
        nom: p.nom.trim(),
        club: typeof p.club === 'string' && p.club.trim() ? p.club.trim() : null,
        poste: ['GK', 'DEF', 'MID', 'ATT'].includes(p.poste) ? p.poste : 'MID',
        valeur: typeof p.valeur === 'number' && isFinite(p.valeur) ? p.valeur : null,
      })) : []

    return {
      statusCode: 200,
      headers,
      body: JSON.stringify({ players, error: parsed.error || null }),
    }
  } catch (e) {
    return { statusCode: 500, headers, body: JSON.stringify({ error: 'Erreur serveur inattendue : ' + (e?.message || e) }) }
  }
}
