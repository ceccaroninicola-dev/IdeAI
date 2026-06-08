/**
 * Cloudflare Worker — Proxy CORS per IdeAI.
 *
 * Inoltra le richieste dall'app Flutter a api.openai.com,
 * aggiungendo gli header CORS necessari per il browser.
 *
 * API KEY:
 * - Se la richiesta ha un header Authorization → usa quella dell'utente
 * - Altrimenti → usa la API key di default (variabile d'ambiente OPENAI_API_KEY)
 *   Questo permette ai beta tester di usare l'AI senza configurare nulla.
 *
 * Configura la key di default con:
 *   npx wrangler secret put OPENAI_API_KEY
 *
 * Deploy:
 *   npx wrangler deploy
 *
 * Piano gratuito Cloudflare Workers: 100.000 richieste/giorno.
 */

// Origini consentite — aggiungi il dominio della tua app
const ORIGINI_CONSENTITE = [
  'http://localhost',       // Sviluppo locale
  'http://127.0.0.1',      // Sviluppo locale
  'https://ceccaroninicola-dev.github.io', // GitHub Pages
];

// URL base dell'API OpenAI
const OPENAI_BASE = 'https://api.openai.com';

export default {
  async fetch(request, env) {
    const tIn = Date.now();

    // Gestisci le richieste preflight CORS (OPTIONS)
    if (request.method === 'OPTIONS') {
      return rispostaCors(request, new Response(null, { status: 204 }));
    }

    // Accetta solo POST (le chiamate a OpenAI sono POST)
    if (request.method !== 'POST') {
      return rispostaCors(request, new Response(
        JSON.stringify({ error: 'Metodo non consentito. Usa POST.' }),
        { status: 405, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    // Costruisci l'URL di destinazione: worker.dev/v1/chat/completions → openai.com/v1/chat/completions
    const url = new URL(request.url);
    const percorso = url.pathname; // es. /v1/chat/completions
    const urlOpenAI = `${OPENAI_BASE}${percorso}`;

    // Inoltra la richiesta a OpenAI con gli stessi header
    const headerInoltro = new Headers();
    headerInoltro.set('Content-Type', 'application/json');

    // Determina quale API key usare:
    // - Se l'utente ha inviato un Authorization header → usa quella (sua key personale)
    // - Altrimenti → usa la key di default dal secret OPENAI_API_KEY del worker
    //   (così i beta tester possono usare l'app senza configurare nulla)
    const authUtente = request.headers.get('Authorization');
    if (authUtente) {
      headerInoltro.set('Authorization', authUtente);
    } else if (env && env.OPENAI_API_KEY) {
      headerInoltro.set('Authorization', `Bearer ${env.OPENAI_API_KEY}`);
    } else {
      return rispostaCors(request, new Response(
        JSON.stringify({
          error: 'API key non disponibile. Configura OPENAI_API_KEY come secret del worker o invia un header Authorization.'
        }),
        { status: 401, headers: { 'Content-Type': 'application/json' } }
      ));
    }

    try {
      const tBeforeOpenai = Date.now();
      const rispostaOpenAI = await fetch(urlOpenAI, {
        method: 'POST',
        headers: headerInoltro,
        body: request.body,
      });
      const tAfterOpenai = Date.now();

      const openaiMs = tAfterOpenai - tBeforeOpenai;
      const workerTotalMs = tAfterOpenai - tIn;

      console.log(`[LATENCY] openai_ms=${openaiMs} worker_total_ms=${workerTotalMs} path=${percorso} status=${rispostaOpenAI.status}`);

      const headers = new Headers(rispostaOpenAI.headers);
      headers.set('X-OpenAI-Duration-Ms', String(openaiMs));
      headers.set('X-Worker-Duration-Ms', String(workerTotalMs));

      const risposta = new Response(rispostaOpenAI.body, {
        status: rispostaOpenAI.status,
        statusText: rispostaOpenAI.statusText,
        headers,
      });

      return rispostaCors(request, risposta);
    } catch (errore) {
      const workerTotalMs = Date.now() - tIn;
      console.log(`[LATENCY] error openai_err=${errore.message} worker_total_ms=${workerTotalMs} path=${percorso}`);
      return rispostaCors(request, new Response(
        JSON.stringify({ error: `Errore proxy: ${errore.message}` }),
        { status: 502, headers: { 'Content-Type': 'application/json' } }
      ));
    }
  },
};

/**
 * Aggiunge gli header CORS alla risposta.
 * Verifica che l'origine sia nella lista consentita.
 */
function rispostaCors(request, risposta) {
  const origine = request.headers.get('Origin') || '';
  const headers = new Headers(risposta.headers);

  // Verifica se l'origine è consentita (controlla prefisso per supportare porte diverse)
  const origineConsentita = ORIGINI_CONSENTITE.some(o => origine.startsWith(o));

  if (origineConsentita) {
    headers.set('Access-Control-Allow-Origin', origine);
  } else {
    // Per sicurezza, consenti comunque ma senza credenziali
    headers.set('Access-Control-Allow-Origin', origine);
  }

  headers.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
  headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  headers.set('Access-Control-Expose-Headers', 'X-OpenAI-Duration-Ms, X-Worker-Duration-Ms');
  headers.set('Access-Control-Max-Age', '86400');

  return new Response(risposta.body, {
    status: risposta.status,
    statusText: risposta.statusText,
    headers,
  });
}
