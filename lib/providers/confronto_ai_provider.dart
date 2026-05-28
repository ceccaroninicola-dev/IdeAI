import 'package:flutter/material.dart';
import 'package:ideai/models/confronto_ai.dart';
import 'package:ideai/models/prompt_generato.dart';
import 'package:ideai/services/api_service.dart';
import 'package:ideai/services/ai_prompts.dart';

/// Provider per la gestione del confronto multi-AI.
/// Gestisce la selezione delle AI, la generazione delle risposte
/// (via GPT-4o-mini o fallback fittizio) e il calcolo della risposta migliore.
class ConfrontoAIProvider extends ChangeNotifier {
  /// Lista completa delle AI disponibili
  static final List<InfoAI> aiDisponibili = [
    const InfoAI(
      nome: 'ChatGPT',
      icona: Icons.chat_bubble_outline,
      colore: Color(0xFF10A37F),
      categorieForti: ['Scrittura', 'Marketing', 'Email', 'Social Media'],
    ),
    const InfoAI(
      nome: 'Claude',
      icona: Icons.auto_awesome,
      colore: Color(0xFFD97706),
      categorieForti: ['Coding', 'Analisi', 'Scrittura', 'Studio'],
    ),
    const InfoAI(
      nome: 'Gemini',
      icona: Icons.diamond_outlined,
      colore: Color(0xFF4285F4),
      categorieForti: ['Analisi', 'Studio', 'Immagini', 'Marketing'],
    ),
    const InfoAI(
      nome: 'Copilot',
      icona: Icons.computer,
      colore: Color(0xFF2B88D8),
      categorieForti: ['Coding', 'Analisi'],
    ),
    const InfoAI(
      nome: 'Mistral',
      icona: Icons.air,
      colore: Color(0xFFFF7000),
      categorieForti: ['Coding', 'Scrittura', 'Email'],
    ),
  ];

  /// AI selezionate dall'utente per il confronto
  final Set<String> _aiSelezionate = {};
  Set<String> get aiSelezionate => _aiSelezionate;

  /// Risultato del confronto
  ConfrontoAI? _confronto;
  ConfrontoAI? get confronto => _confronto;

  /// Stato di caricamento
  bool _staCaricando = false;
  bool get staCaricando => _staCaricando;

  /// Suggerisce le 2-3 AI migliori per la categoria del prompt
  List<InfoAI> suggerisciAI(String categoria) {
    final suggerite = aiDisponibili
        .where((ai) => ai.categorieForti.contains(categoria))
        .take(3)
        .toList();

    if (suggerite.length < 2) {
      for (final ai in aiDisponibili) {
        if (!suggerite.any((s) => s.nome == ai.nome)) {
          suggerite.add(ai);
          if (suggerite.length >= 2) break;
        }
      }
    }

    return suggerite;
  }

  /// Pre-seleziona le AI suggerite
  void preseleziona(List<InfoAI> suggerite) {
    _aiSelezionate.clear();
    for (final ai in suggerite) {
      _aiSelezionate.add(ai.nome);
    }
    notifyListeners();
  }

  /// Toggle selezione di un'AI
  void toggleAI(String nome) {
    if (_aiSelezionate.contains(nome)) {
      _aiSelezionate.remove(nome);
    } else {
      _aiSelezionate.add(nome);
    }
    notifyListeners();
  }

  /// Avvia il confronto: genera risposte per ogni AI selezionata
  /// Usa GPT-4o-mini per simulare le risposte, con fallback fittizio
  Future<void> avviaConfronto(PromptGenerato prompt, String categoria, {required String lang}) async {
    _staCaricando = true;
    notifyListeners();

    final api = ApiService();
    final risposte = <RispostaAI>[];

    for (final nomeAi in _aiSelezionate) {
      final ai = aiDisponibili.firstWhere((a) => a.nome == nomeAi);

      try {
        final json = await api.chiamaAIJson(
          systemPrompt: AiPrompts.getConfrontoPerAI(nomeAi, lang),
          messaggioUtente:
              'Ecco il prompt dell\'utente a cui devi rispondere come $nomeAi:\n\n'
              '${prompt.testoCompleto}\n\n'
              'Categoria: $categoria',
          temperature: 0.9,
          maxTokens: 2000,
        );

        final risposta = json['risposta'] as String? ?? 'Risposta generata.';
        final punteggio =
            (json['punteggio'] as num?)?.toDouble() ?? 4.0;
        final dettaglioJson =
            json['punteggiDettaglio'] as Map<String, dynamic>? ?? {};
        final dettaglio = dettaglioJson.map(
            (k, v) => MapEntry(k, (v as num).toDouble()));

        risposte.add(RispostaAI(
          ai: ai,
          risposta: risposta,
          punteggio: punteggio,
          punteggiDettaglio: dettaglio.isNotEmpty
              ? dettaglio
              : {
                  'Pertinenza': punteggio * 0.98,
                  'Completezza': punteggio * 0.95,
                  'Chiarezza': punteggio * 1.02,
                  'Qualità': punteggio * 0.97,
                },
        ));
      } on ApiException {
        // Fallback per questa AI specifica
        risposte.add(_generaRispostaFittizia(ai, prompt, categoria));
      } catch (_) {
        risposte.add(_generaRispostaFittizia(ai, prompt, categoria));
      }
    }

    // Determina la risposta migliore
    double punteggioMax = 0;
    int indiceMigliore = 0;
    for (var i = 0; i < risposte.length; i++) {
      if (risposte[i].punteggio > punteggioMax) {
        punteggioMax = risposte[i].punteggio;
        indiceMigliore = i;
      }
    }

    final risposteFinali = risposte.asMap().entries.map((entry) {
      return entry.value.conMigliore(entry.key == indiceMigliore);
    }).toList();

    _confronto = ConfrontoAI(
      prompt: prompt,
      risposte: risposteFinali,
      dataConfronto: DateTime.now(),
    );

    _staCaricando = false;
    notifyListeners();
  }

  /// Resetta il confronto
  void reset() {
    _confronto = null;
    _aiSelezionate.clear();
    _staCaricando = false;
    notifyListeners();
  }

  // ===== GENERAZIONE RISPOSTE FITTIZIE (fallback) =====

  RispostaAI _generaRispostaFittizia(
    InfoAI ai,
    PromptGenerato prompt,
    String categoria,
  ) {
    final risposta = _getRispostaPerAI(ai.nome, categoria);
    final punteggio = _getPunteggioPerAI(ai.nome, categoria);

    return RispostaAI(
      ai: ai,
      risposta: risposta,
      punteggio: punteggio,
      punteggiDettaglio: {
        'Pertinenza': (punteggio * 0.98).clamp(0.0, 5.0),
        'Completezza': (punteggio * 0.95).clamp(0.0, 5.0),
        'Chiarezza': (punteggio * 1.02).clamp(0.0, 5.0),
        'Qualità': (punteggio * 0.97).clamp(0.0, 5.0),
      },
    );
  }

  double _getPunteggioPerAI(String nomeAi, String categoria) {
    final ai = aiDisponibili.firstWhere((a) => a.nome == nomeAi);
    final isForte = ai.categorieForti.contains(categoria);

    switch (nomeAi) {
      case 'ChatGPT':
        return isForte ? 4.7 : 4.2;
      case 'Claude':
        return isForte ? 4.8 : 4.3;
      case 'Gemini':
        return isForte ? 4.5 : 4.0;
      case 'Copilot':
        return isForte ? 4.4 : 3.8;
      case 'Mistral':
        return isForte ? 4.3 : 3.9;
      default:
        return 4.0;
    }
  }

  String _getRispostaPerAI(String nomeAi, String categoria) {
    switch (nomeAi) {
      case 'ChatGPT':
        return _risposteChatGPT[categoria] ?? _risposteChatGPT['default']!;
      case 'Claude':
        return _risposteClaude[categoria] ?? _risposteClaude['default']!;
      case 'Gemini':
        return _risposteGemini[categoria] ?? _risposteGemini['default']!;
      case 'Copilot':
        return _risposteCopilot[categoria] ?? _risposteCopilot['default']!;
      case 'Mistral':
        return _risposteMistral[categoria] ?? _risposteMistral['default']!;
      default:
        return 'Risposta generata dall\'AI.';
    }
  }

  // ===== MAPPE DI RISPOSTE FITTIZIE PER AI =====
  // Ogni AI ha risposte per OGNI categoria, con stile, struttura e
  // lunghezza diversi per riflettere la personalità dell'AI.

  static const _risposteChatGPT = {
    'Coding':
        'Ciao! 👋 Ecco la soluzione che ho preparato per te:\n\n'
        '```python\ndef soluzione(dati: list[int]) -> list[int]:\n'
        '    """Elabora i dati con algoritmo ottimizzato."""\n'
        '    risultato = []\n'
        '    for elemento in sorted(dati):\n'
        '        if elemento not in risultato:\n'
        '            risultato.append(elemento)\n'
        '    return risultato\n```\n\n'
        '## Come funziona 🔍\n'
        'La funzione gestisce duplicati e ordinamento in un solo passaggio. '
        'Complessità temporale: O(n log n) per il sorting.\n\n'
        '## Test consigliati ✅\n'
        '- Lista vuota → `[]`\n'
        '- Lista con duplicati → rimozione corretta\n'
        '- Lista già ordinata → nessun cambiamento\n\n'
        '💡 **Pro tip:** Se lavori con dataset molto grandi, considera `set()` per O(1) lookup!',
    'Scrittura':
        'Ecco il testo richiesto, ottimizzato per il tuo pubblico target! ✍️\n\n'
        '---\n\n'
        'In un mondo dove l\'informazione è ovunque, distinguersi richiede autenticità. '
        'Il tuo messaggio deve risuonare con chi lo legge, non solo informare ma ispirare.\n\n'
        '## Tre pilastri per una comunicazione efficace 📌\n'
        '1. **Chiarezza** — Ogni parola ha un peso\n'
        '2. **Empatia** — Scrivi per chi legge, non per chi scrive\n'
        '3. **Azione** — Ogni testo deve portare a un passo successivo\n\n'
        '---\n\n'
        '🚀 Questo approccio garantisce un tasso di engagement superiore del 40% rispetto alla media.\n\n'
        '💡 **Pro tip:** Leggi il testo ad alta voce prima di pubblicarlo — se suona naturale, funziona!',
    'Immagini':
        'Ecco la descrizione visiva dettagliata per generare la tua immagine! 🎨\n\n'
        '## Composizione principale\n'
        'Un\'immagine fotorealistica con illuminazione naturale calda, '
        'soggetto al centro dell\'inquadratura con regola dei terzi applicata.\n\n'
        '## Dettagli tecnici 📐\n'
        '- **Stile**: Fotorealistico con leggera post-produzione cinematografica\n'
        '- **Illuminazione**: Golden hour, ombre morbide e lunghe\n'
        '- **Palette colori**: Toni caldi dominanti (ambra, dorato, arancione tenue)\n'
        '- **Profondità di campo**: Sfondo sfocato (bokeh morbido, f/2.8)\n\n'
        '💡 **Pro tip:** Aggiungi "8K, ultra detailed, award-winning photography" per risultati migliori!',
    'Marketing':
        'Ecco la tua copy di marketing pronta all\'uso! 🚀\n\n'
        '---\n\n'
        '## Hook\n'
        '**Stanco di [problema del target]?** C\'è un modo migliore.\n\n'
        '## Corpo\n'
        'Il nostro prodotto non è solo una soluzione — è un cambio di paradigma. '
        'Ecco cosa ottieni:\n\n'
        '✅ **Risultato 1** — Descrizione beneficio concreto\n'
        '✅ **Risultato 2** — Con numeri e prove sociali\n'
        '✅ **Risultato 3** — ROI misurabile fin dal primo mese\n\n'
        '## CTA\n'
        '👉 **Provalo gratis per 14 giorni.** Nessuna carta di credito richiesta.\n\n'
        '💡 **Pro tip:** Personalizza il hook con il dolore specifico del tuo target!',
    'Email':
        'Ecco la tua email professionale pronta da inviare! 📧\n\n'
        '---\n\n'
        '**Oggetto:** [Oggetto chiaro e diretto]\n\n'
        'Gentile [Nome],\n\n'
        'spero che questa email la trovi bene. Le scrivo in merito a [argomento].\n\n'
        'Vorrei proporre una breve call per discutere come potremmo [obiettivo]. '
        'In base alla mia esperienza, credo che potremmo ottenere [beneficio concreto] '
        'in [timeframe realistico].\n\n'
        'Sarebbe disponibile per una chiamata di 15 minuti questa settimana?\n\n'
        'Cordiali saluti,\n'
        '[Il tuo nome]\n\n'
        '---\n\n'
        '💡 **Pro tip:** Personalizza l\'oggetto con un dato specifico per aumentare il tasso di apertura del 35%!',
    'Analisi':
        'Ecco la mia analisi completa! 📊\n\n'
        '## Executive Summary\n'
        'Dai dati esaminati emergono 3 pattern principali che meritano attenzione.\n\n'
        '## Risultati chiave 🔍\n'
        '1. **Trend positivo** — Crescita del 23% nel periodo analizzato\n'
        '2. **Area critica** — Il segmento X mostra segnali di rallentamento\n'
        '3. **Opportunità** — Il mercato Y è in espansione e sottovalutato\n\n'
        '## Raccomandazioni ✅\n'
        '- Investire nel segmento in crescita\n'
        '- Monitorare l\'area critica con KPI settimanali\n'
        '- Esplorare il mercato Y con un progetto pilota\n\n'
        '💡 **Pro tip:** Rivedi questa analisi mensilmente per tracciare l\'evoluzione dei trend!',
    'Studio':
        'Ecco il materiale di studio preparato per te! 📚\n\n'
        '## Concetti fondamentali\n\n'
        '### 1. Definizione\n'
        'L\'argomento si basa su tre pilastri: [concetto A], [concetto B] e [concetto C].\n\n'
        '### 2. Spiegazione semplice 💡\n'
        'Immagina [analogia semplice]. Ecco, funziona esattamente così!\n\n'
        '### 3. Esempio pratico\n'
        'Prendiamo il caso di [esempio concreto]...\n\n'
        '## Schema di ripasso rapido ✅\n'
        '- Punto chiave 1 → collegato a [concetto]\n'
        '- Punto chiave 2 → si applica quando [condizione]\n'
        '- Punto chiave 3 → eccezione importante: [caso speciale]\n\n'
        '🚀 **Consiglio:** Prova a spiegare questi concetti a qualcun altro — è il modo migliore per verificare di averli capiti!',
    'Social Media':
        'Ecco il tuo post social pronto da pubblicare! 📱\n\n'
        '---\n\n'
        '🔥 **Hook che ferma lo scroll:**\n'
        '"Il 90% delle persone sbaglia questa cosa. Tu sei nel 10%?"\n\n'
        '**Corpo del post:**\n'
        'Ecco 3 lezioni che ho imparato [contesto]:\n\n'
        '1️⃣ [Lezione 1 — sorprendente e controintuitiva]\n'
        '2️⃣ [Lezione 2 — pratica e applicabile subito]\n'
        '3️⃣ [Lezione 3 — cambio di prospettiva]\n\n'
        '**CTA finale:**\n'
        'Quale di queste ti ha colpito di più? Scrivilo nei commenti 👇\n\n'
        '---\n\n'
        '**Hashtag suggeriti:** #crescitapersonale #tips #mindset\n\n'
        '💡 **Pro tip:** Pubblica tra le 8-9 di mattina o le 18-19 per massimo engagement!',
    'default':
        'Ecco la mia risposta completa alla tua richiesta! 💡\n\n'
        '## Analisi del contesto\n'
        'Ho organizzato la risposta per priorità, partendo dagli aspetti più importanti.\n\n'
        '## Soluzione proposta 🎯\n'
        '1. **Primo passo:** Definire gli obiettivi chiari e misurabili\n'
        '2. **Secondo passo:** Identificare le risorse già disponibili\n'
        '3. **Terzo passo:** Implementare e iterare rapidamente\n\n'
        '## Prossimi step ✅\n'
        '- Inizia dal punto 1 questa settimana\n'
        '- Rivedi i progressi dopo 7 giorni\n'
        '- Aggiusta la rotta in base ai risultati\n\n'
        '💡 **Pro tip:** La perfezione è nemica del progresso — meglio iniziare imperfetti che non iniziare mai!',
  };

  static const _risposteClaude = {
    'Coding':
        'Analizziamo il problema in modo sistematico.\n\n'
        'Ho scelto un algoritmo che bilancia leggibilità e performance, '
        'privilegiando la chiarezza del codice.\n\n'
        '```python\nfrom typing import TypeVar\n\nT = TypeVar(\'T\')\n\n'
        'def elabora_dati(dati: list[T], *, ordina: bool = True) -> list[T]:\n'
        '    """Rimuove duplicati mantenendo l\'ordine originale.\n\n'
        '    Args:\n'
        '        dati: Lista di elementi da elaborare\n'
        '        ordina: Se True, ordina il risultato\n\n'
        '    Returns:\n'
        '        Lista senza duplicati\n'
        '    """\n'
        '    visti: set[T] = set()\n'
        '    risultato = [x for x in dati if x not in visti and not visti.add(x)]\n'
        '    return sorted(risultato) if ordina else risultato\n```\n\n'
        'Perché questa soluzione:\n'
        '- Preserva l\'ordine originale (a differenza di `set()`)\n'
        '- Type hints generici per riusabilità\n'
        '- Parametro opzionale per flessibilità\n'
        '- Complessità: O(n) senza ordinamento, O(n log n) con ordinamento\n\n'
        'Una considerazione: se i dati non sono hashable, servirebbe un approccio '
        'diverso basato su confronto diretto, con complessità O(n²).',
    'Scrittura':
        'Ho riflettuto sul tono e il contesto della tua richiesta.\n\n'
        'Le parole migliori sono quelle che non cercano di impressionare, ma di connettere.\n\n'
        'Quando scrivi per un pubblico professionale, ricorda che dietro ogni schermo c\'è '
        'una persona con poco tempo e tante distrazioni. Il tuo testo deve rispettare entrambe le cose.\n\n'
        'La regola del "e quindi?":\n'
        'Dopo ogni frase, chiediti: "e quindi? Perché dovrebbe importare al lettore?". '
        'Se non hai una risposta immediata, quella frase probabilmente non serve.\n\n'
        'Il risultato è un testo che respira: breve dove serve, dettagliato dove conta.\n\n'
        'Ho mantenuto un tono che bilancia professionalità e calore umano. '
        'Se desideri spostare l\'equilibrio verso uno dei due poli, posso adattare la calibrazione.',
    'Immagini':
        'Per questa immagine, vale la pena ragionare sulla composizione prima dei dettagli tecnici.\n\n'
        'Descrizione visiva:\n'
        'Il soggetto principale occupa il terzo sinistro dell\'inquadratura, '
        'creando uno spazio negativo intenzionale sulla destra che guida l\'occhio.\n\n'
        'Scelte stilistiche e motivazioni:\n'
        '- Illuminazione laterale morbida, perché crea profondità senza drammaticità eccessiva\n'
        '- Palette desaturata con un unico accento di colore caldo, per dirigere l\'attenzione\n'
        '- Sfondo leggermente sfocato ma riconoscibile, per contestualizzare senza distrarre\n\n'
        'Una nota sulla resa: i generatori di immagini tendono a sovrasaturare. '
        'Specificare "muted tones" o "subtle colors" aiuta a mantenere l\'eleganza.',
    'Marketing':
        'Ho analizzato la richiesta considerando le dinamiche di persuasione.\n\n'
        'Il testo di marketing efficace non vende un prodotto — risolve un problema '
        'che il lettore già sente ma non ha ancora articolato.\n\n'
        'Proposta:\n\n'
        '[Problema sentito] non è solo un inconveniente. È tempo perso, opportunità mancate, '
        'frustrazione accumulata.\n\n'
        '[Nome prodotto] non aggiunge complessità alla tua giornata. La semplifica.\n\n'
        'Come:\n'
        '- [Beneficio 1] — in termini concreti e misurabili\n'
        '- [Beneficio 2] — con una storia reale di un utente\n'
        '- [Beneficio 3] — il dato che convince anche gli scettici\n\n'
        'La CTA non dovrebbe chiedere un impegno grande. Qualcosa come: '
        '"Prova gratuitamente. Se non funziona per te, non hai perso nulla."\n\n'
        'Un\'osservazione: la copy più efficace è quella che il lettore sente come sincera, '
        'non come tecnica di vendita.',
    'Email':
        'Prima di scrivere, ho considerato il contesto relazionale.\n\n'
        'Un\'email efficace rispetta il tempo del destinatario e chiarisce '
        'le aspettative fin dalle prime righe.\n\n'
        '---\n\n'
        'Oggetto: [Argomento specifico] — richiesta di [azione concreta]\n\n'
        '[Nome],\n\n'
        'le scrivo riguardo a [argomento]. In breve: [riassunto di una riga].\n\n'
        '[Paragrafo con contesto essenziale — solo le informazioni che servono '
        'al destinatario per decidere]\n\n'
        'Quello che propongo è [azione concreta]. Il passo successivo sarebbe '
        '[prossimo step chiaro].\n\n'
        'Resto disponibile per qualsiasi chiarimento.\n\n'
        'Cordiali saluti,\n'
        '[Nome]\n\n'
        '---\n\n'
        'Una nota: ho omesso formule di cortesia ridondanti per mantenere il focus. '
        'Se il rapporto con il destinatario è più formale, posso calibrare diversamente.',
    'Analisi':
        'Ho esaminato la richiesta partendo dai fondamentali.\n\n'
        'Prima dell\'analisi, una premessa metodologica:\n'
        'I dati raccontano storie diverse a seconda di come li interroghi. '
        'Ho scelto di privilegiare le correlazioni causali rispetto alle semplici correlazioni statistiche.\n\n'
        'Risultati dell\'analisi:\n\n'
        '1. Il pattern più significativo è [osservazione principale]. '
        'Questo è rilevante perché [implicazione concreta].\n\n'
        '2. Esiste una tensione tra [variabile A] e [variabile B] che merita attenzione: '
        'ottimizzare una tende a penalizzare l\'altra.\n\n'
        '3. Un dato spesso trascurato: [insight non ovvio che emerge dai dati].\n\n'
        'Cosa farei con questi risultati:\n'
        'Concentrerei le risorse sul punto 1, monitorerei il punto 2 come rischio, '
        'e approfondire il punto 3 come opportunità.\n\n'
        'Un caveat: questa analisi si basa sui dati forniti. '
        'Se ci sono variabili esterne non considerate, le conclusioni potrebbero cambiare.',
    'Studio':
        'Affrontiamo l\'argomento con un approccio che privilegia la comprensione profonda.\n\n'
        'Il concetto fondamentale:\n'
        '[Argomento] si basa su un\'idea semplice che diventa complessa nelle applicazioni. '
        'Partiamo dal nucleo.\n\n'
        'L\'intuizione chiave è questa: [spiegazione con analogia accessibile].\n\n'
        'Perché funziona così (e non in altro modo):\n'
        'Se ci pensi, [ragionamento che costruisce comprensione passo dopo passo]. '
        'Questo spiega perché [conseguenza logica].\n\n'
        'Le eccezioni importanti:\n'
        '- Quando [condizione], il comportamento cambia perché [motivo]\n'
        '- Il caso limite di [scenario] è spesso fonte di errori\n\n'
        'Un modo per verificare se hai capito davvero: '
        'prova a spiegare [concetto] senza usare la parola [termine tecnico]. '
        'Se ci riesci, hai compreso il principio sottostante.',
    'Social Media':
        'Ho ragionato su cosa funziona nei social media e perché.\n\n'
        'La verità sui contenuti che funzionano: non è questione di algoritmo, '
        'ma di risonanza emotiva. Le persone condividono ciò che le fa sentire intelligenti, '
        'utili o comprese.\n\n'
        'Ecco il post:\n\n'
        '---\n\n'
        '[Osservazione controintuitiva che fa riflettere]\n\n'
        '[Sviluppo del pensiero in 2-3 frasi brevi]\n\n'
        '[Conclusione che ribalta la premessa iniziale]\n\n'
        'Cosa ne pensi? [Domanda aperta genuina]\n\n'
        '---\n\n'
        'Una nota sul formato: ho evitato elenchi numerati ed emoji perché '
        'per il tuo tono funziona meglio una struttura narrativa. '
        'L\'autenticità in questo caso è più efficace della formattazione.',
    'default':
        'Ho letto attentamente la tua richiesta e prima di rispondere, '
        'voglio assicurarmi di aver colto le sfumature.\n\n'
        'La tua esigenza principale è ottenere un risultato di qualità '
        'che sia immediatamente utilizzabile.\n\n'
        'Il mio approccio:\n'
        'Ho strutturato la risposta in modo che ogni sezione sia autonoma e utile.\n\n'
        '1. Contesto — Ho inquadrato il problema nel suo scenario reale\n'
        '2. Soluzione — Proposta concreta con passi actionable\n'
        '3. Alternative — Opzioni B e C nel caso la principale non funzioni\n\n'
        'La qualità sta nei dettagli. Ho prestato attenzione a ogni sfumatura della tua richiesta '
        'per fornirti qualcosa che funzioni davvero, non solo sulla carta.\n\n'
        'Se qualche aspetto non è calibrato come lo desideri, indicami la direzione '
        'e posso raffinare la risposta.',
  };

  static const _risposteGemini = {
    'Coding':
        'Implementazione con approccio moderno:\n\n'
        '```python\ndef processa(dati: list) -> list:\n'
        '    # dict.fromkeys preserva ordine e rimuove duplicati (Python 3.7+)\n'
        '    return list(dict.fromkeys(sorted(dati)))\n```\n\n'
        'Performance:\n'
        '- Complessità: O(n log n)\n'
        '- Memoria: O(n)\n'
        '- Benchmark su 1M elementi: ~0.8s\n\n'
        'Alternativa per dataset grandi:\n'
        '`pandas.Series.unique()` è 3-5x più veloce su milioni di elementi.',
    'Scrittura':
        'Punti chiave per il testo richiesto:\n\n'
        '- Formato: adattato al target e al canale di distribuzione\n'
        '- Lunghezza: ottimizzata per la lettura online (media: 3 min)\n'
        '- Struttura: piramide invertita (conclusione → dettagli)\n\n'
        'Testo:\n\n'
        'La comunicazione efficace si misura in risultati, non in parole.\n\n'
        'Tre dati da ricordare:\n'
        '- Il 55% dei lettori online dedica meno di 15 secondi a un articolo\n'
        '- I testi con sottotitoli hanno +36% di lettura completa\n'
        '- Le frasi sotto le 20 parole aumentano la comprensione del 25%\n\n'
        'Applica questi dati al tuo contesto per massimizzare l\'impatto.',
    'Immagini':
        'Specifiche per la generazione dell\'immagine:\n\n'
        '- Soggetto: [descrizione precisa]\n'
        '- Aspect ratio: 16:9\n'
        '- Stile: fotorealistico\n'
        '- Risoluzione target: 2048x1152\n\n'
        'Parametri tecnici consigliati:\n'
        '- CFG scale: 7-9 (per bilanciare aderenza e creatività)\n'
        '- Steps: 30-50 (qualità vs velocità)\n'
        '- Sampler: DPM++ 2M Karras\n\n'
        'Negative prompt suggerito:\n'
        '"blurry, low quality, distorted, watermark, text, oversaturated"\n\n'
        'Nota: questi parametri sono ottimizzati per Stable Diffusion. '
        'Per DALL-E, la descrizione testuale è sufficiente.',
    'Marketing':
        'Analisi e proposta marketing:\n\n'
        'Dati di mercato rilevanti:\n'
        '- Il 72% dei consumatori preferisce contenuti personalizzati (Fonte: HubSpot 2024)\n'
        '- Il tasso di conversione medio per copy mirate è del 4.2%\n\n'
        'Copy proposta:\n\n'
        '[Headline che evidenzia il problema]\n\n'
        'Soluzione:\n'
        '- Beneficio 1 → dato quantificabile\n'
        '- Beneficio 2 → testimonianza reale\n'
        '- Beneficio 3 → garanzia concreta\n\n'
        'CTA: Azione specifica con urgenza naturale (non artificiale)\n\n'
        'A/B test consigliato: testare headline emozionale vs headline con dato numerico.',
    'Email':
        'Template email ottimizzato:\n\n'
        'Dati utili:\n'
        '- Oggetto email: 6-10 parole per massimo tasso di apertura\n'
        '- Lunghezza corpo: 50-125 parole per massimo tasso di risposta\n\n'
        '---\n\n'
        'Oggetto: [Argomento] — [Azione richiesta]\n\n'
        '[Nome],\n\n'
        '[Una frase di contesto]. [Richiesta diretta in una frase].\n\n'
        '[Dettagli essenziali in 2-3 bullet points]:\n'
        '- Punto 1\n'
        '- Punto 2\n'
        '- Punto 3\n\n'
        '[Proposta di next step con data/ora specifica].\n\n'
        'Grazie,\n'
        '[Nome]',
    'Analisi':
        'Risultati dell\'analisi:\n\n'
        'Metodologia: analisi quantitativa con framework [appropriato]\n\n'
        'Findings principali:\n\n'
        '1. Trend primario: +23% crescita nel periodo [X]\n'
        '   - Fonte: [dataset analizzato]\n'
        '   - Confidenza statistica: 95%\n\n'
        '2. Correlazione identificata:\n'
        '   - Variabile A ↔ Variabile B (r = 0.78)\n'
        '   - Implicazione pratica: [azione suggerita]\n\n'
        '3. Anomalia rilevata:\n'
        '   - Il segmento [X] devia dalla media del 2.3σ\n'
        '   - Possibile causa: [ipotesi basata sui dati]\n\n'
        'Raccomandazioni in ordine di priorità:\n'
        '1. [Azione ad alto impatto, basso effort]\n'
        '2. [Azione a medio impatto, medio effort]\n'
        '3. [Azione esplorativa per validare ipotesi]',
    'Studio':
        'Sintesi dello studio sull\'argomento:\n\n'
        'Definizione:\n'
        '[Concetto] in breve: [definizione di una riga]\n\n'
        'Punti chiave:\n'
        '- [Fatto 1] — verificato da [fonte/studio]\n'
        '- [Fatto 2] — applicabile in [contesto]\n'
        '- [Fatto 3] — eccezione nota: [caso speciale]\n\n'
        'Schema rapido:\n'
        '[Concetto A] → porta a → [Concetto B] → implica → [Conseguenza]\n\n'
        'Domande frequenti:\n'
        'Q: [Domanda comune]?\n'
        'A: [Risposta concisa con dato a supporto]\n\n'
        'Risorse per approfondire:\n'
        '- [Tipo di risorsa 1] per fondamenti teorici\n'
        '- [Tipo di risorsa 2] per esercizi pratici',
    'Social Media':
        'Post ottimizzato per engagement:\n\n'
        'Dati di contesto:\n'
        '- Orario migliore per pubblicare: 8:00-9:00 o 12:00-13:00\n'
        '- Lunghezza ottimale: 150-300 caratteri per LinkedIn, 100-150 per X\n'
        '- Post con domanda finale: +2x commenti\n\n'
        'Post:\n\n'
        '[Dato sorprendente o statistica].\n\n'
        'Cosa significa in pratica:\n'
        '→ [Implicazione 1]\n'
        '→ [Implicazione 2]\n'
        '→ [Implicazione 3]\n\n'
        'La domanda è: [domanda aperta basata sui dati]\n\n'
        'Hashtag suggeriti (max 3-5): #[rilevante1] #[rilevante2] #[rilevante3]',
    'default':
        'Punti chiave della risposta:\n\n'
        '- Obiettivo identificato: [sintesi della richiesta]\n'
        '- Approccio consigliato: graduale, con verifiche intermedie\n\n'
        'Piano d\'azione:\n\n'
        '1. [Azione immediata] — completabile in 1-2 giorni\n'
        '2. [Azione di medio termine] — richiede [risorse]\n'
        '3. [Azione di lungo termine] — obiettivo finale\n\n'
        'Metriche per misurare il successo:\n'
        '- [KPI 1]: valore target [X]\n'
        '- [KPI 2]: valore target [Y]\n\n'
        'Prossimo step consigliato: iniziare dal punto 1 e valutare i risultati '
        'dopo una settimana prima di procedere.',
  };

  static const _risposteCopilot = {
    'Coding':
        '```python\n'
        '# Soluzione ottimizzata\n'
        'def soluzione(dati):\n'
        '    return sorted(set(dati))\n'
        '```\n\n'
        'Preservando l\'ordine:\n'
        '```python\n'
        'def mantieni_ordine(dati):\n'
        '    return list(dict.fromkeys(dati))\n'
        '```\n\n'
        'Benchmark: `set()` → O(n), `sorted()` → O(n log n). Production-ready.',
    'Scrittura':
        'Testo generato:\n\n'
        'La comunicazione efficace è diretta. Niente giri di parole.\n\n'
        'Struttura:\n'
        '1. Apri con il punto principale\n'
        '2. Supporta con 2-3 prove\n'
        '3. Chiudi con l\'azione richiesta\n\n'
        'Fatto. Questo formato funziona per email, post e report.',
    'Immagini':
        'Prompt per generazione immagine:\n\n'
        '```\n'
        '[soggetto], [stile], professional photography,\n'
        'studio lighting, 8K, ultra detailed,\n'
        '--ar 16:9 --v 6 --q 2\n'
        '```\n\n'
        'Negative: blurry, low quality, text, watermark\n\n'
        'Per Stable Diffusion aggiungere: steps 40, CFG 7.5, sampler DDIM',
    'Marketing':
        'Copy diretta:\n\n'
        '[Problema] → [Soluzione] → [Prova] → [CTA]\n\n'
        'Template:\n'
        '"[Problema in una frase].\n'
        '[Prodotto] risolve questo in [tempo].\n'
        '[Numero] utenti già lo usano.\n'
        'Provalo → [link]"\n\n'
        'Variante breve per ads: "[Beneficio principale] in [tempo]. Provalo gratis."',
    'Email':
        'Oggetto: [Argomento] — [Azione]\n\n'
        '[Nome],\n\n'
        '[Richiesta in una frase].\n\n'
        'Dettagli:\n'
        '- [Punto 1]\n'
        '- [Punto 2]\n\n'
        'Next step: [azione concreta + deadline]\n\n'
        '[Firma]',
    'Analisi':
        'Risultati:\n\n'
        '```\n'
        'Metrica principale: +23% (p < 0.05)\n'
        'Correlazione A-B:  r = 0.78\n'
        'Anomalia:          segmento X, 2.3σ dalla media\n'
        '```\n\n'
        'Azione: focus su metrica principale, monitorare anomalia.\n'
        'Tool consigliato: pandas + matplotlib per tracking automatico.',
    'Studio':
        'Concetto: [definizione in una riga]\n\n'
        'Come funziona:\n'
        '```\n'
        'Input → [Processo] → Output\n'
        '```\n\n'
        'Punti da ricordare:\n'
        '1. [Regola principale]\n'
        '2. [Eccezione importante]\n'
        '3. [Caso d\'uso comune]\n\n'
        'Pratica: implementa un esempio minimo e poi espandi.',
    'Social Media':
        'Post:\n\n'
        '"[Affermazione diretta].\n\n'
        'Come:\n'
        '→ [Step 1]\n'
        '→ [Step 2]\n'
        '→ [Step 3]\n\n'
        'Link in bio."\n\n'
        'Hashtag: #[1] #[2] #[3]\n'
        'Formato: carosello o testo breve. Pubblicare ore 8-9.',
    'default':
        'Soluzione:\n\n'
        '1. [Azione immediata]\n'
        '2. [Step successivo]\n'
        '3. [Verifica risultato]\n\n'
        'Timeline: 1-2 settimane per i primi risultati.\n'
        'Se serve aiuto su uno step specifico, chiedi.',
  };

  static const _risposteMistral = {
    'Coding':
        'Un approccio funzionale alla soluzione:\n\n'
        '```python\nfrom functools import reduce\n\n'
        'def deduplica_e_ordina(dati: list[int]) -> list[int]:\n'
        '    """Approccio funzionale alla deduplicazione."""\n'
        '    return sorted(\n'
        '        reduce(\n'
        '            lambda acc, x: acc | {x},\n'
        '            dati,\n'
        '            set()\n'
        '        )\n'
        '    )\n```\n\n'
        'Il pattern `reduce` con set union mostra un approccio dichiarativo. '
        'Per produzione, `sorted(set(dati))` resta preferibile per semplicità.\n\n'
        'La scelta tra i due dipende dal contesto: '
        'codice didattico favorisce l\'espressività, codice di produzione la manutenibilità.',
    'Scrittura':
        'La scrittura è un atto di rispetto verso il lettore.\n\n'
        'Ogni frase che scrivi chiede tempo a qualcuno. '
        'Assicurati che quel tempo sia ben speso.\n\n'
        'Il testo che segue applica questo principio:\n\n'
        '---\n\n'
        '[Apertura che stabilisce il contesto in una frase]\n\n'
        '[Sviluppo del tema centrale — due paragrafi al massimo, '
        'ciascuno con un\'idea sola ma sviluppata bene]\n\n'
        '[Chiusura che non ripete, ma rilancia]\n\n'
        '---\n\n'
        'La lunghezza è calibrata: abbastanza per essere utile, '
        'non troppo per essere ignorata.',
    'Immagini':
        'Per l\'immagine richiesta, una composizione ragionata:\n\n'
        'Il soggetto si staglia contro uno sfondo che non compete per l\'attenzione '
        'ma la completa. L\'illuminazione è naturale, laterale, '
        'con ombre che suggeriscono profondità senza drammatizzare.\n\n'
        'Palette: toni terrosi con un singolo accento di colore freddo. '
        'Questa scelta crea un punto focale senza gridare.\n\n'
        'Formato: 16:9, composizione asimmetrica secondo la sezione aurea.\n\n'
        'Il risultato dovrebbe evocare quiete e intenzione — '
        'un\'immagine che si guarda, non che si consuma.',
    'Marketing':
        'Il marketing migliore non sembra marketing.\n\n'
        'Proposta:\n\n'
        'Non parliamo di cosa fa il prodotto. Parliamo di cosa cambia.\n\n'
        'Prima: [situazione frustrante, descritta con empatia]\n'
        'Dopo: [situazione risolta, descritta con sobrietà]\n\n'
        'La differenza è [nome prodotto].\n\n'
        'Un solo numero: [metrica di impatto più convincente]\n'
        'Una sola azione: [CTA essenziale]\n\n'
        'L\'eleganza nella copy sta in ciò che scegli di non dire.',
    'Email':
        'Un\'email che rispetta il destinatario è un\'email che va al punto.\n\n'
        '---\n\n'
        'Oggetto: [Argomento preciso]\n\n'
        '[Nome],\n\n'
        '[Il motivo di questa email in una frase].\n\n'
        '[I dettagli necessari — solo quelli — in un paragrafo breve].\n\n'
        '[La richiesta concreta, formulata in modo che sia facile rispondere '
        'con un sì o un no].\n\n'
        'Grazie per il tempo dedicato.\n\n'
        '[Nome]\n\n'
        '---\n\n'
        'La brevità non è scortesia. È rispetto.',
    'Analisi':
        'L\'analisi rivela tre livelli di lettura.\n\n'
        'Superficie: i numeri mostrano [trend evidente]. '
        'Questo è ciò che tutti vedono.\n\n'
        'Profondità: sotto il trend si nasconde [pattern meno ovvio]. '
        'Questo è ciò che separa l\'analisi dalla lettura superficiale.\n\n'
        'Implicazioni: se [pattern] continua, le conseguenze saranno '
        '[scenario A] nel breve termine e [scenario B] nel medio termine.\n\n'
        'La raccomandazione: agire sul livello intermedio. '
        'Il trend di superficie si correggerà di conseguenza.',
    'Studio':
        'Comprendere [argomento] richiede di abbracciare un paradosso: '
        'è semplice nel principio, complesso nell\'applicazione.\n\n'
        'Il nucleo: [spiegazione essenziale in 2 frasi].\n\n'
        'Perché è controintuitivo: [ragionamento che sfida l\'aspettativa comune].\n\n'
        'Il test della comprensione reale: sai applicare il concetto '
        'in un contesto che non hai mai visto prima. Se riesci solo a ripetere '
        'la definizione, hai memorizzato, non compreso.\n\n'
        'Un esercizio: prendi [situazione quotidiana] e chiediti come '
        '[concetto] la spiega. La risposta ti dirà quanto hai interiorizzato.',
    'Social Media':
        'Un post che funziona è un post che dice una cosa sola, bene.\n\n'
        '---\n\n'
        '[Affermazione precisa che contiene una verità scomoda o sorprendente]\n\n'
        '[Breve sviluppo — 2-3 frasi massimo]\n\n'
        '[Domanda finale che invita alla riflessione, non alla performance]\n\n'
        '---\n\n'
        'Niente hashtag eccessivi. Niente emoji come punteggiatura. '
        'Il contenuto parla da sé quando è autentico.',
    'default':
        'La soluzione ottimale bilancia qualità ed efficienza.\n\n'
        'Analisi della richiesta:\n'
        'Il cuore della tua domanda è [sintesi precisa]. '
        'Gli aspetti secondari — pur importanti — vengono dopo.\n\n'
        'Piano d\'azione:\n'
        '1. [Azione prioritaria] — perché ha il rapporto impatto/sforzo migliore\n'
        '2. [Azione di consolidamento] — per rendere duraturo il risultato\n'
        '3. [Raffinamento] — solo se le prime due hanno funzionato\n\n'
        'Il mio consiglio: resisti alla tentazione di fare tutto insieme. '
        'La sequenza conta più della velocità.',
  };
}
