import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/models/domanda.dart';
import 'package:ideai/providers/sessione_provider.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/widgets/barra_avanzamento.dart';
import 'package:ideai/widgets/banner_ad_widget.dart';
import 'package:ideai/services/ad_service.dart';

/// Schermata delle domande adattive — terza fase del flusso.
/// Design minimal stile Apple: card pulite, teal accento, animazioni fluide.
class DomandeScreen extends StatefulWidget {
  const DomandeScreen({super.key});

  @override
  State<DomandeScreen> createState() => _DomandeScreenState();
}

class _DomandeScreenState extends State<DomandeScreen> {
  // Controller per il campo di testo libero
  final _testoController = TextEditingController();

  // Opzione selezionata per i bottoni opzioni (selezione singola)
  String? _opzioneSelezionata;

  // Chip selezionati per la selezione multipla
  final Set<String> _chipSelezionati = {};

  // Flag per evitare navigazioni multiple alla post-generazione
  bool _haNavigato = false;

  // Flag: l'utente è tornato indietro dalla post-generazione
  bool _ritornatoDaPostGenerazione = false;

  @override
  void initState() {
    super.initState();
    // Pre-carica l'interstitial all'inizio della sessione domande
    AdService().precaricaInterstitial();
  }

  @override
  void dispose() {
    _testoController.dispose();
    super.dispose();
  }

  /// Resetta lo stato di input quando si cambia domanda
  void _resetInput(Domanda domanda, String? rispostaPrecedente) {
    _testoController.clear();
    _opzioneSelezionata = null;
    _chipSelezionati.clear();

    // Se c'è una risposta precedente, ripristinala
    if (rispostaPrecedente != null) {
      switch (domanda.tipoInput) {
        case TipoInput.testoLibero:
          _testoController.text = rispostaPrecedente;
          break;
        case TipoInput.bottoniOpzioni:
          _opzioneSelezionata = rispostaPrecedente;
          break;
        case TipoInput.chipMultipli:
          _chipSelezionati
              .addAll(rispostaPrecedente.split(', ').where((s) => s.isNotEmpty));
          break;
      }
    } else if (domanda.valoreDefault != null) {
      // Altrimenti, imposta il valore di default se presente
      switch (domanda.tipoInput) {
        case TipoInput.testoLibero:
          _testoController.text = domanda.valoreDefault!;
          break;
        case TipoInput.bottoniOpzioni:
          _opzioneSelezionata = domanda.valoreDefault;
          break;
        case TipoInput.chipMultipli:
          _chipSelezionati.addAll(
              domanda.valoreDefault!.split(', ').where((s) => s.isNotEmpty));
          break;
      }
    }
  }

  /// Verifica se l'utente ha fornito una risposta valida
  bool _rispostaValida(TipoInput tipo) {
    switch (tipo) {
      case TipoInput.testoLibero:
        return _testoController.text.trim().isNotEmpty;
      case TipoInput.bottoniOpzioni:
        return _opzioneSelezionata != null;
      case TipoInput.chipMultipli:
        return _chipSelezionati.isNotEmpty;
    }
  }

  /// Restituisce la risposta formattata in base al tipo di input
  String _getRisposta(TipoInput tipo) {
    switch (tipo) {
      case TipoInput.testoLibero:
        return _testoController.text.trim();
      case TipoInput.bottoniOpzioni:
        return _opzioneSelezionata ?? '';
      case TipoInput.chipMultipli:
        return _chipSelezionati.join(', ');
    }
  }

  /// Invia la risposta e passa alla domanda successiva
  void _inviRisposta() {
    final provider = context.read<SessioneProvider>();
    final domanda = provider.domandaCorrente;
    if (domanda == null) return;

    if (!_rispostaValida(domanda.tipoInput)) return;

    provider.rispondiDomanda(_getRisposta(domanda.tipoInput));

    // Se il livello è completato, non navigare automaticamente:
    // il build() mostrerà la schermata di scelta Genera/Approfondisci.
    if (provider.domandaCorrente == null && !provider.sessione.livelloCompletato) {
      _navigaAPostGenerazione();
    }
  }

  /// Genera il prompt immediatamente (bottone "Genera ora")
  void _generaOra() {
    _navigaAPostGenerazione();
  }

  /// Avvia la generazione del prompt e naviga alla schermata post-generazione.
  /// Mostra un interstitial tra la sessione domande e la post-generazione
  /// (massimo 1 ogni 3 minuti). Il flag _haNavigato previene push multipli.
  Future<void> _navigaAPostGenerazione() async {
    if (_haNavigato) return;
    _haNavigato = true;

    final sessione = context.read<SessioneProvider>().sessione;
    final promptProvider = context.read<PromptGeneratoProvider>();

    // Avvia la generazione del prompt via AI
    promptProvider.generaPrompt(
      fraseIniziale: sessione.fraseIniziale,
      categoria: sessione.categoria?.nome ?? 'Scrittura',
      risposte: sessione.tutteLeRisposte,
    );

    // Mostra l'interstitial prima di navigare (se disponibile e non su web)
    if (!kIsWeb) {
      await AdService().mostraInterstitial();
    }

    if (!mounted) return;

    // Naviga alla schermata post-generazione
    Navigator.of(context).pushNamed(AppRoutes.postGenerazione).then((_) {
      // L'utente è tornato indietro dalla post-generazione:
      // segna il flag per evitare il loop di ri-navigazione
      if (mounted) {
        _haNavigato = false;
        _ritornatoDaPostGenerazione = true;
      }
    });
  }

  /// Schermata di completamento livello — scelta tra Genera e Approfondisci
  Widget _buildLivelloCompletato(
    dynamic sessione,
    SessioneProvider provider,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final livello = sessione.livello as int;
    final puoApprofondire = provider.puoApprofondire;

    final l10n = AppLocalizations.of(context)!;

    // Titoli e descrizioni per ogni livello
    String titoloLivello;
    String descrizione;
    IconData icona;
    switch (livello) {
      case 1:
        titoloLivello = l10n.questioningLevelOverviewTitle;
        descrizione = l10n.questioningLevelOverviewDesc;
        icona = Icons.check_circle_outline;
        break;
      case 2:
        titoloLivello = l10n.questioningLevelDeepDiveTitle;
        descrizione = l10n.questioningLevelDeepDiveDesc;
        icona = Icons.zoom_in;
        break;
      default:
        titoloLivello = l10n.questioningLevelDetailsTitle;
        descrizione = l10n.questioningLevelDetailsDesc;
        icona = Icons.done_all;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(sessione.categoria?.nome ?? l10n.questioningFallbackTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.questioningCancelTooltip,
          onPressed: () {
            context.read<SessioneProvider>().resetSessione();
            Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: l10n.tooltipBackToHome,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Barra di avanzamento
              BarraAvanzamento(
                percentuale: sessione.percentualeCompletamento as double,
                domandaCorrente: sessione.domande.length as int,
                totaleDomande: sessione.domande.length as int,
                onTapDomanda: (_) {},
              ),
              const SizedBox(height: 12),

              // Badge livello
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  l10n.questioningLevelProgress(livello.toString()),
                  style: TextStyle(
                    color: colorScheme.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Contenuto centrale
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icona grande
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        icona,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Titolo
                    Text(
                      titoloLivello,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),

                    // Descrizione
                    Text(
                      descrizione,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Contatore risposte
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          if (!isDark)
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 1),
                            ),
                        ],
                      ),
                      child: Text(
                        l10n.questioningAnswersCollected(sessione.risposte.length.toString()),
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottoni azione
              Column(
                children: [
                  // Bottone primario: Genera ora
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _navigaAPostGenerazione(),
                      icon: const Icon(Icons.auto_awesome, size: 20),
                      label: Text(l10n.questioningGenerateNowButton),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  // Bottone secondario: Approfondisci (solo se livello < 3)
                  if (puoApprofondire) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => provider.approfondisci(),
                        icon: const Icon(Icons.search_rounded, size: 20),
                        label: Text(
                          livello == 1
                              ? l10n.questioningDeepen
                              : l10n.questioningLastDetails,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Banner pubblicitario
              const BannerAdWidget(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final provider = context.watch<SessioneProvider>();
    final sessione = provider.sessione;

    final l10n = AppLocalizations.of(context)!;

    // Se sta caricando domande di approfondimento
    if (provider.staApprofondendo) {
      return Scaffold(
        appBar: AppBar(
          title: Text(sessione.categoria?.nome ?? l10n.questioningFallbackTitle),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                l10n.questioningPreparingQuestions,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    // Se il livello è completato, mostra la scelta Genera/Approfondisci
    if (sessione.livelloCompletato && sessione.domande.isNotEmpty) {
      if (_ritornatoDaPostGenerazione) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
        return Scaffold(
          body: Center(
            child: CircularProgressIndicator(color: colorScheme.primary),
          ),
        );
      }
      return _buildLivelloCompletato(sessione, provider, colorScheme);
    }

    final domanda = provider.domandaCorrente;

    // Se tutte le domande sono completate (edge case):
    if (domanda == null && sessione.domande.isNotEmpty) {
      if (_ritornatoDaPostGenerazione) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });
      } else if (!_haNavigato) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigaAPostGenerazione();
        });
      }
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    if (domanda == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      // Permette al contenuto di rimpicciolirsi quando appare la tastiera,
      // così il campo di testo libero resta visibile sopra di essa
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(sessione.categoria?.nome ?? l10n.questioningFallbackTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: l10n.questioningCancelTooltip,
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(l10n.questioningCancelTitle),
                content: Text(
                  l10n.questioningCancelContent,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(l10n.questioningCancelContinue),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      context.read<SessioneProvider>().resetSessione();
                      Navigator.of(context).pushNamedAndRemoveUntil(
                        AppRoutes.home,
                        (route) => false,
                      );
                    },
                    child: Text(l10n.questioningCancelConfirm),
                  ),
                ],
              ),
            );
          },
        ),
        actions: [
          // Bottone Home — torna alla Home cancellando lo stack
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: l10n.tooltipBackToHome,
            onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
              AppRoutes.home,
              (route) => false,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contenuto principale delle domande
            Expanded(
              child: _DomandeBody(
                domanda: domanda,
                sessione: sessione,
                provider: provider,
                colorScheme: colorScheme,
                testoController: _testoController,
                opzioneSelezionata: _opzioneSelezionata,
                chipSelezionati: _chipSelezionati,
                onResetInput: _resetInput,
                onOpzioneSelezionata: (val) =>
                    setState(() => _opzioneSelezionata = val),
                onChipToggle: (chip) {
                  setState(() {
                    if (_chipSelezionati.contains(chip)) {
                      _chipSelezionati.remove(chip);
                    } else {
                      _chipSelezionati.add(chip);
                    }
                  });
                },
                onInviaRisposta: _inviRisposta,
                onGeneraOra: _generaOra,
                onTestoChanged: () => setState(() {}),
              ),
            ),
            // Banner pubblicitario in basso (solo su mobile, non su web)
            const BannerAdWidget(),
          ],
        ),
      ),
    );
  }
}

/// Widget separato per il body della schermata domande.
/// Gestisce il layout e l'animazione tra una domanda e l'altra.
class _DomandeBody extends StatefulWidget {
  final Domanda domanda;
  final dynamic sessione;
  final SessioneProvider provider;
  final ColorScheme colorScheme;
  final TextEditingController testoController;
  final String? opzioneSelezionata;
  final Set<String> chipSelezionati;
  final void Function(Domanda, String?) onResetInput;
  final ValueChanged<String> onOpzioneSelezionata;
  final ValueChanged<String> onChipToggle;
  final VoidCallback onInviaRisposta;
  final VoidCallback onGeneraOra;
  final VoidCallback onTestoChanged;

  const _DomandeBody({
    required this.domanda,
    required this.sessione,
    required this.provider,
    required this.colorScheme,
    required this.testoController,
    required this.opzioneSelezionata,
    required this.chipSelezionati,
    required this.onResetInput,
    required this.onOpzioneSelezionata,
    required this.onChipToggle,
    required this.onInviaRisposta,
    required this.onGeneraOra,
    required this.onTestoChanged,
  });

  @override
  State<_DomandeBody> createState() => _DomandeBodyState();
}

class _DomandeBodyState extends State<_DomandeBody> {
  // Tiene traccia dell'ultimo id domanda visualizzato per resettare l'input
  String? _ultimaDomandaId;

  // FocusNode per il campo di testo libero — serve a scrollare automaticamente
  // il campo sopra la tastiera quando riceve il focus
  final _testoFocusNode = FocusNode();

  // Chiave globale del TextField per Scrollable.ensureVisible
  final _testoFieldKey = GlobalKey();

  @override
  void didUpdateWidget(covariant _DomandeBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.domanda.id != _ultimaDomandaId) {
      _ultimaDomandaId = widget.domanda.id;
      final rispostaPrecedente =
          widget.sessione.risposte[widget.domanda.testo] as String?;
      widget.onResetInput(widget.domanda, rispostaPrecedente);
    }
  }

  @override
  void initState() {
    super.initState();
    _ultimaDomandaId = widget.domanda.id;
    final rispostaPrecedente =
        widget.sessione.risposte[widget.domanda.testo] as String?;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onResetInput(widget.domanda, rispostaPrecedente);
    });
    // Quando il campo testo riceve il focus, scorri per renderlo visibile
    _testoFocusNode.addListener(_onTestoFocusChange);
  }

  /// Porta il TextField in vista quando riceve il focus (dopo l'apertura tastiera)
  void _onTestoFocusChange() {
    if (_testoFocusNode.hasFocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final ctx = _testoFieldKey.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: 0.1,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _testoFocusNode.removeListener(_onTestoFocusChange);
    _testoFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Barra di avanzamento in alto
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: BarraAvanzamento(
            percentuale: widget.sessione.percentualeCompletamento as double,
            domandaCorrente: widget.sessione.domandaCorrente as int,
            totaleDomande: widget.sessione.domande.length as int,
            onTapDomanda: (indice) {
              final diff =
                  (widget.sessione.domandaCorrente as int) - indice;
              for (var i = 0; i < diff; i++) {
                widget.provider.domandaPrecedente();
              }
            },
          ),
        ),
        const SizedBox(height: 8),

        // Indicatore livello corrente
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: widget.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  l10n.questioningLevelProgress((widget.sessione.livello as int).toString()),
                  style: TextStyle(
                    color: widget.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _etichettaLivello(widget.sessione.livello as int, l10n),
                style: TextStyle(
                  color: widget.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Contenuto principale — domanda e input
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            // Chiude la tastiera quando si trascina la vista
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.03, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(widget.domanda.id),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Testo della domanda
                  Text(
                    widget.domanda.testo,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),

                  // Widget di input in base al tipo di domanda
                  _buildInput(isDark),
                ],
              ),
            ),
          ),
        ),

        // Barra inferiore con bottoni di navigazione
        _buildBarraInferiore(isDark),
      ],
    );
  }

  /// Costruisce il widget di input appropriato
  Widget _buildInput(bool isDark) {
    switch (widget.domanda.tipoInput) {
      case TipoInput.testoLibero:
        return _buildInputTestoLibero();
      case TipoInput.bottoniOpzioni:
        return _buildInputBottoni(isDark);
      case TipoInput.chipMultipli:
        return _buildInputChip();
    }
  }

  /// Input di tipo testo libero — campo di testo con bordi morbidi
  Widget _buildInputTestoLibero() {
    return TextField(
      key: _testoFieldKey,
      controller: widget.testoController,
      focusNode: _testoFocusNode,
      maxLines: 5,
      onChanged: (_) => widget.onTestoChanged(),
      decoration: InputDecoration(
        hintText: widget.domanda.placeholder ?? AppLocalizations.of(context)!.questioningInputPlaceholder,
        hintMaxLines: 2,
        hintStyle: TextStyle(
          color: widget.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: widget.colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: widget.colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.all(18),
      ),
    );
  }

  /// Input di tipo bottoni opzioni — card Apple-style con selezione singola
  Widget _buildInputBottoni(bool isDark) {
    return Column(
      children: widget.domanda.opzioni.map((opzione) {
        final selezionato = widget.opzioneSelezionata == opzione;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: double.infinity,
            decoration: BoxDecoration(
              color: selezionato
                  ? widget.colorScheme.primary.withValues(alpha: 0.08)
                  : widget.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selezionato
                    ? widget.colorScheme.primary
                    : isDark
                        ? widget.colorScheme.outlineVariant
                        : Colors.transparent,
                width: selezionato ? 1.5 : 0.5,
              ),
              boxShadow: [
                if (!isDark && !selezionato)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 1),
                  ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => widget.onOpzioneSelezionata(opzione),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      // Indicatore di selezione — cerchio teal
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selezionato
                                ? widget.colorScheme.primary
                                : widget.colorScheme.outline,
                            width: selezionato ? 2 : 1.5,
                          ),
                          color: selezionato
                              ? widget.colorScheme.primary
                              : Colors.transparent,
                        ),
                        child: selezionato
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      // Testo dell'opzione
                      Expanded(
                        child: Text(
                          opzione,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                                fontWeight: selezionato
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      // Badge "Suggerito" — teal leggero
                      if (opzione == widget.domanda.valoreDefault &&
                          !selezionato)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.colorScheme.primary
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            AppLocalizations.of(context)!.questioningSuggested,
                            style: TextStyle(
                              color: widget.colorScheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Input di tipo chip multipli — chip teal con selezione multipla
  Widget _buildInputChip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.questioningChipInstruction,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: widget.domanda.opzioni.map((opzione) {
            final selezionato = widget.chipSelezionati.contains(opzione);
            return FilterChip(
              label: Text(opzione),
              selected: selezionato,
              onSelected: (_) => widget.onChipToggle(opzione),
              showCheckmark: true,
              checkmarkColor: Colors.white,
              selectedColor: widget.colorScheme.primary.withValues(alpha: 0.15),
              backgroundColor: widget.colorScheme.surfaceContainerLow,
              side: BorderSide(
                color: selezionato
                    ? widget.colorScheme.primary
                    : widget.colorScheme.outlineVariant,
                width: selezionato ? 1.5 : 0.5,
              ),
              labelStyle: TextStyle(
                color: selezionato
                    ? widget.colorScheme.primary
                    : widget.colorScheme.onSurface,
                fontWeight:
                    selezionato ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );
          }).toList(),
        ),
        // Riepilogo dei chip selezionati
        if (widget.chipSelezionati.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.questioningSelectedItems(widget.chipSelezionati.join(", ")),
            style: TextStyle(
              color: widget.colorScheme.primary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }

  /// Barra inferiore — stile Apple con ombra sottile
  Widget _buildBarraInferiore(bool isDark) {
    final puoTornareIndietro = widget.provider.puoTornareIndietro;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Riga con bottoni Indietro e Avanti
          Row(
            children: [
              // Bottone "Indietro"
              if (puoTornareIndietro)
                Container(
                  decoration: BoxDecoration(
                    color: widget.colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () => widget.provider.domandaPrecedente(),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                    tooltip: AppLocalizations.of(context)!.questioningPreviousTooltip,
                    color: widget.colorScheme.onSurface,
                  ),
                ),
              if (puoTornareIndietro) const SizedBox(width: 12),

              // Bottone "Avanti" / "Completa" — teal pieno
              Expanded(
                child: ElevatedButton(
                  onPressed: _isRispostaValida()
                      ? widget.onInviaRisposta
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    widget.provider.isUltimaDomanda
                        ? AppLocalizations.of(context)!.questioningComplete
                        : AppLocalizations.of(context)!.questioningNext,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Bottone "Genera ora" — teal testo
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: widget.onGeneraOra,
              icon: Icon(Icons.bolt, size: 18,
                  color: widget.colorScheme.primary),
              label: Text(
                AppLocalizations.of(context)!.questioningGenerateNow,
                style: TextStyle(color: widget.colorScheme.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Restituisce l'etichetta descrittiva per il livello corrente
  String _etichettaLivello(int livello, AppLocalizations l10n) {
    switch (livello) {
      case 1:
        return l10n.questioningLabelGeneral;
      case 2:
        return l10n.questioningLabelDeepDive;
      case 3:
        return l10n.questioningLabelFinalDetails;
      default:
        return '';
    }
  }

  /// Verifica se la risposta corrente è valida
  bool _isRispostaValida() {
    switch (widget.domanda.tipoInput) {
      case TipoInput.testoLibero:
        return widget.testoController.text.trim().isNotEmpty;
      case TipoInput.bottoniOpzioni:
        return widget.opzioneSelezionata != null;
      case TipoInput.chipMultipli:
        return widget.chipSelezionati.isNotEmpty;
    }
  }
}
