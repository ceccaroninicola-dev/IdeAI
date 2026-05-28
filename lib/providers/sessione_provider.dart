import 'package:flutter/material.dart';
import 'package:ideai/models/categoria_rilevata.dart';
import 'package:ideai/models/domanda.dart';
import 'package:ideai/models/sessione_prompt.dart';
import 'package:ideai/services/api_service.dart';
import 'package:ideai/services/ai_prompts.dart';

/// Provider per la gestione della sessione di creazione prompt.
/// Gestisce il flusso a 3 livelli progressivi:
/// - Fase 0: analisi punti focali (invisibile)
/// - Livello 1: 5 domande macro
/// - Livello 2: approfondimento risposte generiche
/// - Livello 3: dettagli finali
class SessioneProvider extends ChangeNotifier {
  /// Sessione corrente di creazione prompt
  SessionePrompt _sessione = const SessionePrompt(fraseIniziale: '');

  /// Indica se l'analisi della frase è in corso
  bool _staAnalizzando = false;

  /// Indica se sta caricando domande di approfondimento
  bool _staApprofondendo = false;

  /// Eventuale errore durante le chiamate API
  String? _errore;

  // -- Getter --

  SessionePrompt get sessione => _sessione;
  bool get staAnalizzando => _staAnalizzando;
  bool get staApprofondendo => _staApprofondendo;
  String? get errore => _errore;

  /// Restituisce la domanda corrente, o null se completate
  Domanda? get domandaCorrente {
    if (_sessione.domande.isEmpty ||
        _sessione.domandaCorrente >= _sessione.domande.length) {
      return null;
    }
    return _sessione.domande[_sessione.domandaCorrente];
  }

  /// Verifica se siamo all'ultima domanda del livello corrente
  bool get isUltimaDomanda {
    return _sessione.domandaCorrente >= _sessione.domande.length - 1;
  }

  /// Verifica se si può tornare alla domanda precedente
  bool get puoTornareIndietro => _sessione.domandaCorrente > 0;

  /// Verifica se l'utente può approfondire (livello 1 o 2)
  bool get puoApprofondire => _sessione.livello < 3;

  // -- Azioni --

  /// Resetta l'errore
  void cancellaErrore() {
    _errore = null;
    notifyListeners();
  }

  /// Avvia una nuova sessione con la frase libera dell'utente.
  /// Esegue: categoria → punti focali → domande livello 1.
  Future<void> avviaSessione(String fraseLibera, {required String lang}) async {
    _sessione = SessionePrompt(fraseIniziale: fraseLibera);
    _staAnalizzando = true;
    _errore = null;
    notifyListeners();

    final api = ApiService();
    debugPrint('[Sessione] Avvio sessione — userKey: ${api.apiKeyConfigurata}');

    // STEP 1: Rileva la categoria con l'AI
    CategoriaRilevata categoria;
    bool categoriaViaAI = false;
    try {
      debugPrint('[Sessione] STEP 1: Analisi categoria via AI...');
      final json = await api.chiamaAIJson(
        systemPrompt: AiPrompts.analisiCategoria(lang),
        messaggioUtente: fraseLibera,
        temperature: 0.3,
        maxTokens: 500,
      );
      debugPrint('[Sessione] STEP 1: Categoria ricevuta: ${json['categoria']}');
      categoria = CategoriaRilevata(
        nome: json['categoria'] as String? ?? 'Scrittura',
        icona: json['icona'] as String? ?? 'edit_note',
        riepilogo: json['riepilogo'] as String? ??
            'Vuoi creare un prompt personalizzato.',
        sottocategoria: json['sottocategoria'] as String?,
        elementiChiave: (json['elementiChiave'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            _estraiElementiChiave(fraseLibera),
      );
      categoriaViaAI = true;
    } on ApiException catch (e) {
      debugPrint('[Sessione] STEP 1: Errore API → ${e.messaggio}');
      _errore = e.messaggio;
      categoria = _rilevaCategoria(fraseLibera);
    } catch (e, stack) {
      debugPrint('[Sessione] STEP 1: Eccezione inattesa → $e');
      debugPrint('[Sessione] STEP 1: Stack → $stack');
      _errore = 'Errore inatteso durante l\'analisi.';
      categoria = _rilevaCategoria(fraseLibera);
    }

    // STEP 2: Genera i punti focali (fase 0 invisibile)
    List<String> puntiFocali = [];
    try {
      debugPrint('[Sessione] STEP 2: Generazione punti focali...');
      final json = await api.chiamaAIJson(
        systemPrompt: AiPrompts.analisiPuntiFocali(lang),
        messaggioUtente: 'RICHIESTA UTENTE: "$fraseLibera"\n'
            'CATEGORIA: ${categoria.nome}\n'
            'SOTTOCATEGORIA: ${categoria.sottocategoria ?? "N/A"}',
        temperature: 0.5,
        maxTokens: 1500,
      );
      final lista = json['puntiFocali'] as List<dynamic>? ?? [];
      puntiFocali = lista.map((e) => e.toString()).toList();
      debugPrint('[Sessione] STEP 2: ${puntiFocali.length} punti focali generati');
    } catch (e) {
      debugPrint('[Sessione] STEP 2: Errore punti focali → $e');
      // Non critico: le domande del livello 1 possono funzionare senza
    }

    // STEP 3: Genera le 5 domande macro (livello 1)
    List<Domanda> domande;
    try {
      debugPrint('[Sessione] STEP 3: Generazione domande livello 1...');
      final json = await api.chiamaAIJson(
        systemPrompt: AiPrompts.domandeLivello1(lang),
        messaggioUtente: 'FRASE INIZIALE: "$fraseLibera"\n'
            'CATEGORIA: ${categoria.nome}\n'
            'SOTTOCATEGORIA: ${categoria.sottocategoria ?? "N/A"}\n'
            'ELEMENTI CHIAVE: ${categoria.elementiChiave.join(", ")}\n'
            'PUNTI FOCALI: ${puntiFocali.join("; ")}',
        temperature: 0.6,
        maxTokens: 2000,
      );
      domande = _parsaDomande(json);
      debugPrint('[Sessione] STEP 3: ${domande.length} domande livello 1');
      if (categoriaViaAI && _errore == null) {
        // tutto ok
      } else if (!categoriaViaAI && _errore != null) {
        debugPrint('[Sessione] Domande OK ma categoria fallback');
      }
    } on ApiException catch (e) {
      debugPrint('[Sessione] STEP 3: Errore API → ${e.messaggio}');
      _errore ??= e.messaggio;
      domande = _generaDomandeFittizie(categoria.nome);
    } catch (e, stack) {
      debugPrint('[Sessione] STEP 3: Eccezione inattesa → $e');
      debugPrint('[Sessione] STEP 3: Stack → $stack');
      _errore ??= 'Errore inatteso durante la generazione delle domande.';
      domande = _generaDomandeFittizie(categoria.nome);
    }

    _sessione = _sessione.copyWith(
      categoria: categoria,
      domande: domande,
      puntiFocali: puntiFocali,
      livello: 1,
      percentualeCompletamento: 0.0,
      livelloCompletato: false,
    );
    _staAnalizzando = false;
    notifyListeners();
  }

  /// Conferma la categoria rilevata e passa alle domande
  void confermCategoria() {
    _sessione = _sessione.copyWith(
      percentualeCompletamento: 0.05,
    );
    notifyListeners();
  }

  /// Salva la risposta alla domanda corrente e passa alla successiva.
  /// Se era l'ultima domanda del livello, segna il livello come completato.
  void rispondiDomanda(String risposta) {
    final nuoveRisposte = Map<String, String>.from(_sessione.risposte);
    final domanda = domandaCorrente;
    if (domanda == null) return;

    // Usa il testo della domanda come chiave per dare contesto all'AI
    nuoveRisposte[domanda.testo] = risposta;

    final nuovoIndice = _sessione.domandaCorrente + 1;
    final completatoTutteLeDomande = nuovoIndice >= _sessione.domande.length;

    // Calcola percentuale basata sul livello
    final baseLivello = (_sessione.livello - 1) / 3.0;
    final avanzamentoLivello = (nuovoIndice / _sessione.domande.length) / 3.0;
    final percentuale = baseLivello + avanzamentoLivello;

    _sessione = _sessione.copyWith(
      risposte: nuoveRisposte,
      domandaCorrente: nuovoIndice,
      percentualeCompletamento: percentuale.clamp(0.0, 1.0),
      livelloCompletato: completatoTutteLeDomande,
    );
    notifyListeners();
  }

  /// L'utente sceglie di approfondire: genera domande di livello successivo.
  /// Salva le risposte del livello corrente e prepara il prossimo.
  Future<void> approfondisci({required String lang}) async {
    if (_sessione.livello >= 3) return;

    _staApprofondendo = true;
    notifyListeners();

    final api = ApiService();
    final livelloSuccessivo = _sessione.livello + 1;

    // Salva le risposte del livello corrente nell'archivio
    final nuoveRisposteLivelli =
        Map<String, Map<String, String>>.from(_sessione.risposteLivelli);
    nuoveRisposteLivelli['livello_${_sessione.livello}'] =
        Map<String, String>.from(_sessione.risposte);

    // Costruisci il contesto con le risposte fin qui raccolte
    _sessione = _sessione.copyWith(
      risposteLivelli: nuoveRisposteLivelli,
    );
    final contesto = _sessione.riepilogoRisposte;

    // Scegli il prompt per il livello giusto
    final systemPrompt = livelloSuccessivo == 2
        ? AiPrompts.domandeLivello2(lang)
        : AiPrompts.domandeLivello3(lang);

    List<Domanda> nuoveDomande;
    try {
      debugPrint('[Sessione] Approfondimento livello $livelloSuccessivo...');
      final json = await api.chiamaAIJson(
        systemPrompt: systemPrompt,
        messaggioUtente: 'FRASE INIZIALE: "${_sessione.fraseIniziale}"\n'
            'CATEGORIA: ${_sessione.categoria?.nome ?? "Generale"}\n'
            'PUNTI FOCALI: ${_sessione.puntiFocali.join("; ")}\n\n'
            'RISPOSTE GIÀ RACCOLTE:\n$contesto',
        temperature: 0.6,
        maxTokens: 3000,
      );
      nuoveDomande = _parsaDomande(json);
      debugPrint('[Sessione] ${nuoveDomande.length} domande livello $livelloSuccessivo');
    } on ApiException catch (e) {
      debugPrint('[Sessione] Errore approfondimento → ${e.messaggio}');
      _errore = e.messaggio;
      nuoveDomande = [];
    } catch (e) {
      debugPrint('[Sessione] Eccezione approfondimento → $e');
      _errore = 'Errore durante l\'approfondimento.';
      nuoveDomande = [];
    }

    if (nuoveDomande.isEmpty) {
      // Se non si riescono a generare domande, torna allo stato precedente
      _staApprofondendo = false;
      notifyListeners();
      return;
    }

    _sessione = _sessione.copyWith(
      livello: livelloSuccessivo,
      domande: nuoveDomande,
      risposte: const {},
      domandaCorrente: 0,
      livelloCompletato: false,
    );
    _staApprofondendo = false;
    notifyListeners();
  }

  /// Torna alla domanda precedente
  void domandaPrecedente() {
    if (!puoTornareIndietro) return;

    _sessione = _sessione.copyWith(
      domandaCorrente: _sessione.domandaCorrente - 1,
      livelloCompletato: false,
      percentualeCompletamento:
          ((_sessione.domandaCorrente - 1) / _sessione.domande.length)
              .clamp(0.0, 1.0),
    );
    notifyListeners();
  }

  /// Resetta la sessione per iniziarne una nuova
  void resetSessione() {
    _sessione = const SessionePrompt(fraseIniziale: '');
    _staAnalizzando = false;
    _staApprofondendo = false;
    _errore = null;
    notifyListeners();
  }

  // -- Parsing risposta AI --

  /// Parsa le domande dalla risposta JSON dell'AI
  List<Domanda> _parsaDomande(Map<String, dynamic> json) {
    final listaDomande = json['domande'] as List<dynamic>? ?? [];
    if (listaDomande.isEmpty) return _generaDomandeFittizie('Scrittura');

    return listaDomande.map((d) {
      final mappa = d as Map<String, dynamic>;
      return Domanda(
        id: mappa['id'] as String? ?? 'q_${listaDomande.indexOf(d)}',
        testo: mappa['testo'] as String? ?? 'Domanda',
        tipoInput: _parsaTipoInput(mappa['tipoInput'] as String?),
        opzioni: (mappa['opzioni'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        placeholder: mappa['placeholder'] as String?,
        valoreDefault: mappa['valoreDefault'] as String?,
      );
    }).toList();
  }

  /// Converte la stringa del tipo input nel enum
  TipoInput _parsaTipoInput(String? tipo) {
    switch (tipo) {
      case 'testoLibero':
        return TipoInput.testoLibero;
      case 'bottoniOpzioni':
        return TipoInput.bottoniOpzioni;
      case 'chipMultipli':
        return TipoInput.chipMultipli;
      default:
        return TipoInput.testoLibero;
    }
  }

  // -- Metodi di fallback con dati fittizi --

  /// Rileva la categoria dalla frase (fallback senza AI)
  CategoriaRilevata _rilevaCategoria(String frase) {
    final fraseLower = frase.toLowerCase();

    if (fraseLower.contains('codice') ||
        fraseLower.contains('programm') ||
        fraseLower.contains('funzione') ||
        fraseLower.contains('bug') ||
        fraseLower.contains('api') ||
        fraseLower.contains('code') ||
        fraseLower.contains('python') ||
        fraseLower.contains('javascript')) {
      return CategoriaRilevata(
        nome: 'Coding',
        icona: 'code',
        riepilogo:
            'Vuoi creare un prompt per assistenza nella programmazione.',
        sottocategoria: 'Sviluppo Software',
        elementiChiave: _estraiElementiChiave(frase),
      );
    }

    if (fraseLower.contains('immagine') ||
        fraseLower.contains('foto') ||
        fraseLower.contains('disegn') ||
        fraseLower.contains('illustr') ||
        fraseLower.contains('visual')) {
      return CategoriaRilevata(
        nome: 'Immagini',
        icona: 'image',
        riepilogo:
            'Vuoi creare un prompt per generare immagini o contenuti visivi.',
        sottocategoria: 'Generazione Immagini',
        elementiChiave: _estraiElementiChiave(frase),
      );
    }

    if (fraseLower.contains('post') ||
        fraseLower.contains('linkedin') ||
        fraseLower.contains('social') ||
        fraseLower.contains('instagram') ||
        fraseLower.contains('twitter') ||
        fraseLower.contains('marketing')) {
      return CategoriaRilevata(
        nome: 'Scrittura',
        icona: 'edit_note',
        riepilogo:
            'Vuoi creare un prompt per scrivere contenuti per i social media.',
        sottocategoria: 'Social Media / Marketing',
        elementiChiave: _estraiElementiChiave(frase),
      );
    }

    if (fraseLower.contains('email') ||
        fraseLower.contains('mail') ||
        fraseLower.contains('lettera') ||
        fraseLower.contains('messaggio')) {
      return CategoriaRilevata(
        nome: 'Scrittura',
        icona: 'edit_note',
        riepilogo:
            'Vuoi creare un prompt per scrivere email o comunicazioni.',
        sottocategoria: 'Comunicazione',
        elementiChiave: _estraiElementiChiave(frase),
      );
    }

    return CategoriaRilevata(
      nome: 'Scrittura',
      icona: 'edit_note',
      riepilogo:
          'Vuoi creare un prompt per generare testo o contenuti scritti.',
      sottocategoria: 'Generale',
      elementiChiave: _estraiElementiChiave(frase),
    );
  }

  /// Estrae parole chiave dalla frase (fallback senza AI)
  List<String> _estraiElementiChiave(String frase) {
    final paroleComuni = {
      'voglio', 'vorrei', 'creare', 'fare', 'un', 'una', 'il', 'la', 'lo',
      'le', 'gli', 'di', 'a', 'da', 'in', 'con', 'su', 'per', 'tra', 'fra',
      'che', 'come', 'mi', 'ho', 'bisogno', 'aiutami', 'scrivi', 'genera',
      'crea', 'fammi', 'puoi', 'potresti', 'e', 'o', 'ma', 'non', 'del',
      'dei', 'delle', 'della', 'dello', 'al', 'alla', 'alle',
    };

    return frase
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((parola) =>
            parola.length > 2 && !paroleComuni.contains(parola))
        .take(5)
        .toList();
  }

  /// Genera domande fittizie di livello 1 (fallback senza AI)
  List<Domanda> _generaDomandeFittizie(String categoria) {
    switch (categoria) {
      case 'Coding':
        return const [
          Domanda(id: 'linguaggio', testo: 'In quale linguaggio stai lavorando?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Python', 'JavaScript', 'Dart/Flutter', 'Java', 'Altro'], valoreDefault: 'Python'),
          Domanda(id: 'tipo_aiuto', testo: 'Che tipo di aiuto ti serve?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Scrivere codice nuovo', 'Correggere un bug', 'Ottimizzare', 'Spiegare']),
          Domanda(id: 'contesto', testo: 'Descrivi brevemente il contesto del progetto.', tipoInput: TipoInput.testoLibero, placeholder: 'Es. App web con React per gestire...'),
          Domanda(id: 'livello_dettaglio', testo: 'Quanto dettagliata vuoi la risposta?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Solo codice', 'Codice con commenti', 'Spiegazione passo passo', 'Tutorial completo'], valoreDefault: 'Codice con commenti'),
          Domanda(id: 'requisiti_extra', testo: 'Requisiti specifici?', tipoInput: TipoInput.chipMultipli, opzioni: ['Performance', 'Sicurezza', 'Test', 'Documentazione', 'Semplicità']),
        ];
      case 'Immagini':
        return const [
          Domanda(id: 'stile', testo: 'Quale stile visivo preferisci?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Fotorealistico', 'Illustrazione digitale', 'Cartoon / Anime', 'Arte astratta', 'Minimalista']),
          Domanda(id: 'soggetto', testo: 'Descrivi il soggetto dell\'immagine.', tipoInput: TipoInput.testoLibero, placeholder: 'Es. Un gatto che legge un libro...'),
          Domanda(id: 'atmosfera', testo: 'Che atmosfera vuoi comunicare?', tipoInput: TipoInput.chipMultipli, opzioni: ['Luminosa', 'Cupa', 'Romantica', 'Futuristica', 'Nostalgica', 'Energetica']),
          Domanda(id: 'colori', testo: 'Preferenze sui colori?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Caldi', 'Freddi', 'Bianco e nero', 'Pastello', 'Nessuna'], valoreDefault: 'Nessuna'),
          Domanda(id: 'formato', testo: 'Formato/dimensione?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Quadrato 1:1', 'Orizzontale 16:9', 'Verticale 9:16', 'Libero']),
        ];
      default:
        return const [
          Domanda(id: 'tipo_contenuto', testo: 'Che tipo di contenuto vuoi creare?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Post social', 'Email', 'Articolo / Blog', 'Testo creativo', 'Altro']),
          Domanda(id: 'tono', testo: 'Quale tono vuoi usare?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Formale', 'Informale', 'Ironico', 'Ispirazionale', 'Tecnico'], valoreDefault: 'Informale'),
          Domanda(id: 'pubblico', testo: 'A chi è rivolto?', tipoInput: TipoInput.chipMultipli, opzioni: ['Professionisti', 'Studenti', 'Pubblico generico', 'Manager', 'Creativi']),
          Domanda(id: 'lunghezza', testo: 'Quanto lungo il risultato?', tipoInput: TipoInput.bottoniOpzioni, opzioni: ['Breve (1-2 paragrafi)', 'Medio (3-5 paragrafi)', 'Lungo (articolo completo)'], valoreDefault: 'Medio (3-5 paragrafi)'),
          Domanda(id: 'dettagli_extra', testo: 'Dettagli specifici da includere?', tipoInput: TipoInput.testoLibero, placeholder: 'Es. Menziona il lancio del prodotto...'),
        ];
    }
  }
}
