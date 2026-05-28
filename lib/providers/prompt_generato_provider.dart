import 'package:flutter/material.dart';
import 'package:ideai/models/prompt_generato.dart';
import 'package:ideai/models/prompt_template.dart';
import 'package:ideai/services/api_service.dart';
import 'package:ideai/services/ai_prompts.dart';

/// Provider per la gestione del prompt generato.
/// Usa GPT-4o-mini per la generazione, con fallback ai dati fittizi.
class PromptGeneratoProvider extends ChangeNotifier {
  /// Il prompt generato corrente
  PromptGenerato? _prompt;

  /// Indica se la generazione è in corso
  bool _staGenerando = false;

  /// Eventuale errore durante la generazione
  String? _errore;

  /// Prompt ottimizzato per un'AI specifica (cache)
  String? _promptOttimizzato;

  /// AI per cui è stato ottimizzato il prompt
  String? _aiOttimizzata;

  /// Testo originale del prompt (prima di modifiche manuali)
  String? _testoOriginale;

  // -- Getter --

  PromptGenerato? get prompt => _prompt;
  bool get staGenerando => _staGenerando;
  String? get errore => _errore;
  String? get promptOttimizzato => _promptOttimizzato;
  String? get aiOttimizzata => _aiOttimizzata;
  String? get testoOriginale => _testoOriginale;

  /// Genera un prompt a partire dalle risposte della sessione.
  /// Chiama sempre l'AI via proxy (che inietta la key di default);
  /// il fallback fittizio si attiva solo se la chiamata fallisce.
  Future<void> generaPrompt({
    required String fraseIniziale,
    required String categoria,
    required Map<String, String> risposte,
    required String lang,
  }) async {
    _staGenerando = true;
    _errore = null;
    _promptOttimizzato = null;
    _aiOttimizzata = null;
    notifyListeners();

    final api = ApiService();
    debugPrint('[PromptGen] Avvio generazione — userKey: ${api.apiKeyConfigurata}');

    try {
      // Costruisci il messaggio con tutte le informazioni raccolte
      final messaggioUtente = _costruisciMessaggio(
          fraseIniziale, categoria, risposte, lang);

      debugPrint('[PromptGen] Chiamata AI in corso...');
      final json = await api.chiamaAIJson(
        systemPrompt: AiPrompts.generazionePrompt(lang),
        messaggioUtente: messaggioUtente,
        temperature: 0.7,
        maxTokens: 3000,
      );

      _prompt = _parsaPromptDaJson(json);
      _testoOriginale = _prompt!.testoCompleto;
      debugPrint('[PromptGen] Prompt generato: ${_prompt!.sezioni.length} sezioni');
    } on ApiException catch (e) {
      debugPrint('[PromptGen] Errore API → ${e.messaggio}');
      _errore = e.messaggio;
      // Fallback ai dati fittizi
      _prompt = _creaPromptFittizio(fraseIniziale, categoria, risposte);
    } catch (e, stack) {
      debugPrint('[PromptGen] Eccezione inattesa → $e');
      debugPrint('[PromptGen] Stack → $stack');
      _errore = 'Errore inatteso durante la generazione.';
      _prompt = _creaPromptFittizio(fraseIniziale, categoria, risposte);
    }

    _staGenerando = false;
    notifyListeners();
  }

  /// Ottimizza il prompt per un'AI di destinazione specifica.
  /// Restituisce il testo ottimizzato.
  Future<String?> ottimizzaPerAI(String nomeAI, {required String lang}) async {
    if (_prompt == null) return null;

    // Se è già ottimizzato per la stessa AI, usa la cache
    if (_aiOttimizzata == nomeAI && _promptOttimizzato != null) {
      return _promptOttimizzato;
    }

    final api = ApiService();

    try {
      final risultato = await api.chiamaAI(
        systemPrompt: AiPrompts.ottimizzazionePerAI(lang),
        messaggioUtente: 'AI di destinazione: $nomeAI\n\n'
            'Prompt originale:\n${_prompt!.testoCompleto}',
        temperature: 0.5,
        maxTokens: 2000,
      );
      _promptOttimizzato = risultato;
      _aiOttimizzata = nomeAI;
      notifyListeners();
      return risultato;
    } on ApiException {
      // Fallback: restituisci il prompt originale
      return _prompt!.testoCompleto;
    } catch (_) {
      return _prompt!.testoCompleto;
    }
  }

  /// Aggiorna il contenuto di una sezione specifica
  void aggiornaSezione(int indice, String nuovoContenuto) {
    if (_prompt == null) return;
    _prompt = _prompt!.conSezioneAggiornata(indice, nuovoContenuto);
    _promptOttimizzato = null; // Invalida la cache
    _aiOttimizzata = null;
    _ricalcolaPunteggi();
    notifyListeners();
  }

  /// Applica un suggerimento di miglioramento
  void applicaSuggerimento(SuggerimentoMiglioramento suggerimento) {
    if (_prompt == null) return;

    _prompt = _prompt!.conSezioneAggiornata(
      suggerimento.sezioneIndice,
      suggerimento.testoDopo,
    );

    final nuoviSuggerimenti = List<SuggerimentoMiglioramento>.from(
      _prompt!.suggerimenti,
    )..removeWhere((s) => s.etichetta == suggerimento.etichetta);

    _prompt = _prompt!.conPunteggiAggiornati(
      suggerimenti: nuoviSuggerimenti,
    );
    _promptOttimizzato = null;
    _aiOttimizzata = null;
    _ricalcolaPunteggi();
    notifyListeners();
  }

  /// Carica un prompt da un template della libreria
  void caricaDaTemplate(PromptTemplate template) {
    _prompt = PromptGenerato(
      sezioni: template.sezioni,
      punteggioGlobale: template.popolarita,
      punteggiCriteri: {
        'Chiarezza': (template.popolarita * 0.95).clamp(0.0, 5.0),
        'Specificità': (template.popolarita * 0.90).clamp(0.0, 5.0),
        'Completezza': (template.popolarita * 0.92).clamp(0.0, 5.0),
        'Struttura': (template.popolarita * 0.98).clamp(0.0, 5.0),
        'Coerenza': (template.popolarita * 0.96).clamp(0.0, 5.0),
      },
      suggerimenti: const [],
    );
    _testoOriginale = _prompt!.testoCompleto;
    _staGenerando = false;
    _promptOttimizzato = null;
    _aiOttimizzata = null;
    notifyListeners();
  }

  /// Carica un prompt già esistente (es. dalla cronologia)
  void caricaPrompt(PromptGenerato prompt) {
    _prompt = prompt;
    _testoOriginale = prompt.testoCompleto;
    _staGenerando = false;
    _promptOttimizzato = null;
    _aiOttimizzata = null;
    notifyListeners();
  }

  /// Resetta il provider
  void reset() {
    _prompt = null;
    _staGenerando = false;
    _errore = null;
    _promptOttimizzato = null;
    _aiOttimizzata = null;
    _testoOriginale = null;
    notifyListeners();
  }

  /// Migliora una singola sezione del prompt tramite AI.
  /// Restituisce il testo migliorato o null in caso di errore.
  Future<String?> miglioraSezione(int indice, {required String lang}) async {
    if (_prompt == null || indice >= _prompt!.sezioni.length) return null;
    final sezione = _prompt!.sezioni[indice];
    final api = ApiService();
    try {
      final risultato = await api.chiamaAI(
        systemPrompt: AiPrompts.miglioramentoSezione(lang),
        messaggioUtente: 'TITOLO SEZIONE: ${sezione.titolo}\n\n'
            'CONTENUTO ATTUALE:\n${sezione.contenuto}',
        temperature: 0.6,
        maxTokens: 1500,
      );
      return risultato.trim();
    } catch (e) {
      debugPrint('[PromptGen] Errore miglioramento sezione → $e');
      return null;
    }
  }

  // -- Metodi privati --

  /// Costruisce il messaggio per l'AI con tutte le informazioni raccolte.
  /// Le risposte sono presentate come coppie domanda→risposta per dare
  /// all'AI il contesto necessario a rielaborarle in un prompt fluido.
  String _costruisciMessaggio(
    String fraseIniziale,
    String categoria,
    Map<String, String> risposte,
    String lang,
  ) {
    final isEn = lang != 'it';
    final buffer = StringBuffer();
    buffer.writeln(isEn ? 'ORIGINAL USER REQUEST:' : 'RICHIESTA ORIGINALE DELL\'UTENTE:');
    buffer.writeln('"$fraseIniziale"');
    buffer.writeln('');
    buffer.writeln(isEn ? 'CATEGORY: $categoria' : 'CATEGORIA: $categoria');
    buffer.writeln('');
    if (risposte.isNotEmpty) {
      buffer.writeln(isEn
          ? 'DATA COLLECTED FROM QUESTIONS (RAW answers to be REWORKED):'
          : 'DATI RACCOLTI DALLE DOMANDE (risposte GREZZE da RIELABORARE):');
      buffer.writeln(isEn
          ? '⚠️ These are short/abbreviated answers. Do NOT copy them, REWRITE them.'
          : '⚠️ Queste sono risposte brevi/abbreviate. NON copiarle, RISCRIVILE.');
      buffer.writeln('');
      risposte.forEach((domanda, risposta) {
        buffer.writeln(isEn ? '• Question: "$domanda"' : '• Domanda: "$domanda"');
        buffer.writeln(isEn ? '  Answer: "$risposta"' : '  Risposta: "$risposta"');
        buffer.writeln('');
      });
    }
    buffer.writeln(isEn ? 'FINAL INSTRUCTIONS:' : 'ISTRUZIONI FINALI:');
    buffer.writeln(isEn
        ? 'Generate the final prompt by completely REWORKING the data above.'
        : 'Genera il prompt finale RIELABORANDO completamente i dati qui sopra.');
    buffer.writeln(isEn
        ? 'The answers are RAW data - do NOT copy them, INTEGRATE them into fluent sentences.'
        : 'Le risposte sono dati GREZZI — NON copiarle, INTEGRALE in frasi fluide.');
    buffer.writeln(isEn
        ? 'The prompt must START with an action verb (Write, Generate, Create, Analyze).'
        : 'Il prompt deve INIZIARE con un verbo d\'azione (Scrivi, Genera, Crea, Analizza).');
    buffer.writeln(isEn
        ? 'It must be a DIRECT instruction ready to paste into an AI.'
        : 'Deve essere un\'istruzione DIRETTA pronta da incollare su un\'AI.');
    buffer.writeln(isEn
        ? 'NEVER include "Yes", "No", isolated numbers or single words without context.'
        : 'MAI includere "Sì", "No", numeri isolati o parole singole senza contesto.');
    return buffer.toString();
  }

  /// Parsa il prompt dalla risposta JSON dell'AI
  PromptGenerato _parsaPromptDaJson(Map<String, dynamic> json) {
    // Parsa le sezioni
    final sezioniJson = json['sezioni'] as List<dynamic>? ?? [];
    final sezioni = sezioniJson.map((s) {
      final mappa = s as Map<String, dynamic>;
      return SezionePrompt(
        titolo: mappa['titolo'] as String? ?? 'Sezione',
        icona: mappa['icona'] as String? ?? 'article',
        contenuto: mappa['contenuto'] as String? ?? '',
        colore: (mappa['colore'] as num?)?.toInt() ?? 0xFF009688,
      );
    }).toList();

    // Se non ci sono sezioni, usa fallback
    if (sezioni.isEmpty) {
      return _creaPromptFittizio('', 'Scrittura', {});
    }

    // Parsa i punteggi
    final punteggioGlobale =
        (json['punteggioGlobale'] as num?)?.toDouble() ?? 4.0;
    final punteggiCriteriJson =
        json['punteggiCriteri'] as Map<String, dynamic>? ?? {};
    final punteggiCriteri = punteggiCriteriJson.map(
        (k, v) => MapEntry(k, (v as num).toDouble()));

    // Parsa i suggerimenti
    final suggerimentiJson = json['suggerimenti'] as List<dynamic>? ?? [];
    final suggerimenti = suggerimentiJson.map((s) {
      final mappa = s as Map<String, dynamic>;
      return SuggerimentoMiglioramento(
        etichetta: mappa['etichetta'] as String? ?? 'Suggerimento',
        icona: mappa['icona'] as String? ?? 'lightbulb',
        sezioneIndice: (mappa['sezioneIndice'] as num?)?.toInt() ?? 0,
        testoPrima: mappa['testoPrima'] as String? ?? '',
        testoDopo: mappa['testoDopo'] as String? ?? '',
        descrizione: mappa['descrizione'] as String? ?? '',
      );
    }).toList();

    return PromptGenerato(
      sezioni: sezioni,
      punteggioGlobale: punteggioGlobale,
      punteggiCriteri: punteggiCriteri,
      suggerimenti: suggerimenti,
    );
  }

  /// Ricalcola i punteggi dopo una modifica (simulato)
  void _ricalcolaPunteggi() {
    if (_prompt == null) return;

    final lunghezzaTotale = _prompt!.sezioni
        .fold<int>(0, (sum, s) => sum + s.contenuto.length);

    final fattore = (lunghezzaTotale / 800).clamp(0.5, 1.0);
    final base = 3.5;

    _prompt = _prompt!.conPunteggiAggiornati(
      punteggioGlobale: double.parse(
        (base + (1.5 * fattore)).toStringAsFixed(1),
      ),
      punteggiCriteri: {
        'Chiarezza': double.parse(
            (3.8 + (1.2 * fattore)).clamp(0.0, 5.0).toStringAsFixed(1)),
        'Specificità': double.parse(
            (3.2 + (1.5 * fattore)).clamp(0.0, 5.0).toStringAsFixed(1)),
        'Completezza': double.parse(
            (3.5 + (1.3 * fattore)).clamp(0.0, 5.0).toStringAsFixed(1)),
        'Struttura': double.parse(
            (4.0 + (0.8 * fattore)).clamp(0.0, 5.0).toStringAsFixed(1)),
        'Coerenza': double.parse(
            (3.9 + (1.0 * fattore)).clamp(0.0, 5.0).toStringAsFixed(1)),
      },
    );
  }

  /// Crea un prompt fittizio (fallback senza AI).
  /// Integra SEMPRE la frase iniziale nel prompt generato.
  PromptGenerato _creaPromptFittizio(
    String fraseIniziale,
    String categoria,
    Map<String, String> risposte,
  ) {
    final sezioni = _generaSezioni(fraseIniziale, categoria, risposte);

    return PromptGenerato(
      sezioni: sezioni,
      punteggioGlobale: 4.2,
      punteggiCriteri: const {
        'Chiarezza': 4.5,
        'Specificità': 3.8,
        'Completezza': 4.0,
        'Struttura': 4.6,
        'Coerenza': 4.3,
      },
      suggerimenti: _generaSuggerimenti(sezioni),
    );
  }

  /// Genera le sezioni del prompt in base alla categoria (fallback).
  /// Integra SEMPRE la frase iniziale dell'utente nel prompt.
  List<SezionePrompt> _generaSezioni(
    String fraseIniziale,
    String categoria,
    Map<String, String> risposte,
  ) {
    // Costruisci la parte dei dettagli aggiuntivi dalle risposte
    final dettagliAggiuntivi = StringBuffer();
    risposte.forEach((chiave, valore) {
      if (valore.isNotEmpty) {
        dettagliAggiuntivi.write(' $valore.');
      }
    });
    final extra = dettagliAggiuntivi.toString().trim();

    // Scegli titolo e icona in base alla categoria
    final titolo = _titoloPerCategoria(categoria);
    final icona = _iconaPerCategoria(categoria);

    // Il prompt finale parte SEMPRE dalla frase iniziale dell'utente
    // e aggiunge i dettagli raccolti dalle domande
    String contenuto;

    switch (categoria) {
      case 'Coding':
        final linguaggio = risposte['linguaggio'] ?? '';
        final linguaggioDesc = linguaggio.isNotEmpty ? ' in $linguaggio' : '';
        contenuto = '$fraseIniziale.$linguaggioDesc '
            'Il codice deve essere pulito, ben documentato e seguire le '
            'best practices. Gestisci i casi limite e gli errori.';
        if (extra.isNotEmpty) contenuto += ' $extra';
        break;

      case 'Immagini':
        final stile = risposte['stile'] ?? '';
        final stileDesc = stile.isNotEmpty ? ' Stile: $stile.' : '';
        final atmosfera = risposte['atmosfera'] ?? '';
        final atmosferaDesc = atmosfera.isNotEmpty ? ' Atmosfera: $atmosfera.' : '';
        contenuto = 'Genera un\'immagine: $fraseIniziale.$stileDesc$atmosferaDesc '
            'Composizione ben bilanciata con punto focale chiaro. '
            'Alta risoluzione, senza elementi testuali nell\'immagine.';
        if (extra.isNotEmpty) contenuto += ' $extra';
        break;

      default:
        final tono = risposte['tono'] ?? '';
        final tonoDesc = tono.isNotEmpty ? ' Tono: $tono.' : '';
        final lunghezza = risposte['lunghezza'] ?? '';
        final lunghezzaDesc = lunghezza.isNotEmpty ? ' Lunghezza: $lunghezza.' : '';
        contenuto = '$fraseIniziale.$tonoDesc$lunghezzaDesc';
        if (extra.isNotEmpty) contenuto += ' $extra';
        break;
    }

    return [
      SezionePrompt(
        titolo: titolo,
        icona: icona,
        contenuto: contenuto,
        colore: 0xFF7C3AED,
      ),
    ];
  }

  /// Restituisce il titolo della sezione in base alla categoria
  String _titoloPerCategoria(String categoria) {
    switch (categoria) {
      case 'Scrittura':
        return 'Istruzione Testo';
      case 'Marketing':
        return 'Istruzione Marketing';
      case 'Email':
        return 'Istruzione Email';
      case 'Analisi':
        return 'Istruzione Analisi';
      case 'Studio':
        return 'Istruzione Studio';
      case 'Social Media':
        return 'Istruzione Social';
      default:
        return 'Istruzione';
    }
  }

  /// Restituisce l'icona della sezione in base alla categoria
  String _iconaPerCategoria(String categoria) {
    switch (categoria) {
      case 'Scrittura':
        return 'edit_note';
      case 'Marketing':
        return 'campaign';
      case 'Email':
        return 'email';
      case 'Analisi':
        return 'analytics';
      case 'Studio':
        return 'school';
      case 'Social Media':
        return 'share';
      default:
        return 'list';
    }
  }

  /// Genera suggerimenti di miglioramento contestuali (fallback).
  /// Tutti i prompt sono ora a sezione unica (istruzione diretta).
  List<SuggerimentoMiglioramento> _generaSuggerimenti(
    List<SezionePrompt> sezioni,
  ) {
    final contenuto = sezioni[0].contenuto;
    final isImmagine = sezioni[0].titolo == 'Descrizione Immagine';

    if (isImmagine) {
      return [
        SuggerimentoMiglioramento(
          etichetta: 'Più dettagli visivi',
          icona: 'lightbulb',
          sezioneIndice: 0,
          testoPrima: contenuto,
          testoDopo:
              '$contenuto '
              'Dettagli aggiuntivi: texture realistiche, riflessi naturali, '
              'micro-dettagli sulle superfici.',
          descrizione:
              'Aggiunge dettagli visivi specifici per un\'immagine '
              'più ricca e realistica.',
        ),
        SuggerimentoMiglioramento(
          etichetta: 'Migliora illuminazione',
          icona: 'lightbulb',
          sezioneIndice: 0,
          testoPrima: contenuto,
          testoDopo: contenuto.replaceFirst(
              'illuminazione naturale',
              'illuminazione cinematografica con rim light e ombre profonde'),
          descrizione:
              'Rende l\'illuminazione più drammatica e professionale.',
        ),
        SuggerimentoMiglioramento(
          etichetta: 'Aggiungi qualità',
          icona: 'add_circle',
          sezioneIndice: 0,
          testoPrima: contenuto,
          testoDopo:
              '$contenuto '
              '8K, ultra detailed, award-winning, professional quality.',
          descrizione:
              'Aggiunge tag di qualità per risultati più '
              'dettagliati e professionali.',
        ),
      ];
    }

    // Suggerimenti per tutte le altre categorie (sezione unica)
    return [
      SuggerimentoMiglioramento(
        etichetta: 'Aggiungi esempio',
        icona: 'lightbulb',
        sezioneIndice: 0,
        testoPrima: contenuto,
        testoDopo:
            '$contenuto\n\n'
            'Esempio di risultato atteso: [descrivi qui un esempio concreto '
            'del risultato che vorresti ottenere].',
        descrizione:
            'Aggiunge un esempio concreto di output atteso '
            'per guidare meglio l\'AI nella generazione.',
      ),
      SuggerimentoMiglioramento(
        etichetta: 'Più specifico',
        icona: 'format_align_left',
        sezioneIndice: 0,
        testoPrima: contenuto,
        testoDopo:
            '$contenuto '
            'Struttura il risultato con: titolo, sottotitoli, '
            'corpo principale diviso in sezioni chiare.',
        descrizione:
            'Aggiunge dettagli sulla struttura '
            'del formato di output per risultati più precisi.',
      ),
      SuggerimentoMiglioramento(
        etichetta: 'Aggiungi vincoli',
        icona: 'block',
        sezioneIndice: 0,
        testoPrima: contenuto,
        testoDopo:
            '$contenuto '
            'Limita la risposta a massimo 500 parole. '
            'Non includere riferimenti generici o contenuti banali.',
        descrizione:
            'Aggiunge vincoli specifici per '
            'controllare meglio l\'output generato.',
      ),
    ];
  }
}
