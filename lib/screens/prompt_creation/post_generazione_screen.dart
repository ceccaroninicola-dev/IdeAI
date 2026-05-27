import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/models/prompt_generato.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/providers/sessione_provider.dart';
import 'package:ideai/providers/cronologia_provider.dart';
import 'package:ideai/providers/confronto_ai_provider.dart';
import 'package:ideai/providers/community_provider.dart';
import 'package:ideai/models/prompt_pubblico.dart';
import 'package:ideai/services/export_service.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/utils/category_localizer.dart';

/// Schermata post-generazione — mostra il prompt generato con:
/// - Anteprima in due viste (semplice/strutturata)
/// - Modifica inline per sezione
/// - Scoring a stelle con breakdown per criterio
/// - Suggerimenti di miglioramento con anteprima prima/dopo
/// - Barra azioni (copia, esporta, salva)
class PostGenerazioneScreen extends StatefulWidget {
  const PostGenerazioneScreen({super.key});

  @override
  State<PostGenerazioneScreen> createState() => _PostGenerazioneScreenState();
}

class _PostGenerazioneScreenState extends State<PostGenerazioneScreen> {
  /// true = vista strutturata, false = vista semplice
  bool _vistaStrutturata = false;

  /// Indice della sezione in fase di modifica (-1 = nessuna)
  int _sezioneInModifica = -1;

  /// Controller per il campo di modifica inline
  final _editController = TextEditingController();

  /// AI di destinazione selezionata (null = non ancora scelta)
  String? _aiSelezionata;

  /// Indice della sezione in fase di miglioramento AI (-1 = nessuna)
  int _sezioneMigliorandosi = -1;

  /// Template predefiniti per tipo di sezione
  static const _templatePerSezione = {
    'Ruolo': 'Agisci come un [esperto di X] con [Y anni di esperienza] '
        'specializzato in [Z]. Hai una profonda conoscenza di [ambito] e '
        'sei in grado di [competenza chiave].',
    'Contesto': 'L\'utente è [descrizione del profilo] che ha bisogno di '
        '[obiettivo principale]. Il contesto è [situazione specifica] con '
        '[vincoli o requisiti particolari]. Il risultato verrà utilizzato per '
        '[scopo finale].',
    'Istruzioni': '1. [Primo step operativo]\n2. [Secondo step operativo]\n'
        '3. [Terzo step operativo]\n4. [Quarto step operativo]\n\n'
        'Per ogni step, fornisci [tipo di dettaglio richiesto]. '
        'Assicurati di [requisito di qualità].',
    'Formato output': 'Organizza la risposta in:\n'
        '1) Sommario esecutivo (max 3 righe)\n'
        '2) Corpo principale suddiviso in sezioni con intestazioni\n'
        '3) Elenchi puntati per i punti chiave\n'
        '4) Tabella comparativa (se applicabile)\n'
        '5) Conclusione con prossimi passi',
    'Vincoli': 'Lunghezza: [X] parole/caratteri.\nTono: [professionale/informale/'
        'tecnico].\nLingua: [lingua target].\nNon includere: [elementi da evitare].\n'
        'Formato: [markdown/testo semplice/HTML].',
  };

  @override
  void dispose() {
    _editController.dispose();
    super.dispose();
  }

  /// Mappa nome icona → IconData Material
  IconData _getIcona(String nome) {
    switch (nome) {
      case 'person':
        return Icons.person_outline;
      case 'info':
        return Icons.info_outline;
      case 'list':
        return Icons.checklist_rounded;
      case 'format_align_left':
        return Icons.format_align_left;
      case 'block':
        return Icons.block_outlined;
      case 'lightbulb':
        return Icons.lightbulb_outline;
      case 'record_voice_over':
        return Icons.record_voice_over_outlined;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<PromptGeneratoProvider>();
    final prompt = provider.prompt;

    // Schermata di caricamento durante la generazione
    if (provider.staGenerando || prompt == null) {
      return Scaffold(
        appBar: AppBar(title: Text(AppLocalizations.of(context)!.postGenGenerating)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)!.postGenLoadingSubtitle,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Disabilita il tasto back del browser/dispositivo:
    // torna alla Home cancellando lo stack
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          );
        }
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.postGenAppBarTitle),
        automaticallyImplyLeading: false,
        leading: TextButton.icon(
          icon: const Icon(Icons.home, size: 20),
          label: Text(
            AppLocalizations.of(context)!.postGenHomeButton,
            style: const TextStyle(fontSize: 14),
          ),
          onPressed: () => Navigator.of(context).pushNamedAndRemoveUntil(
            AppRoutes.home,
            (route) => false,
          ),
        ),
        leadingWidth: 120,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Contenuto scrollabile
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Scoring a stelle ---
                    _buildScoring(prompt, colorScheme, isDark),
                    const SizedBox(height: 20),

                    // --- Toggle vista semplice/strutturata ---
                    _buildToggleVista(colorScheme),
                    const SizedBox(height: 16),

                    // --- Anteprima del prompt ---
                    _vistaStrutturata
                        ? _buildVistaStrutturata(prompt, colorScheme, isDark)
                        : _buildVistaSemplice(prompt, colorScheme, isDark),
                    const SizedBox(height: 24),

                    // --- Suggerimenti di miglioramento ---
                    if (prompt.suggerimenti.isNotEmpty) ...[
                      Text(
                        AppLocalizations.of(context)!.postGenSectionImproveTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      _buildSuggerimenti(prompt, colorScheme),
                    ],
                  ],
                ),
              ),
            ),

            // --- Barra azioni in basso ---
            _buildBarraAzioni(prompt, colorScheme, isDark),
          ],
        ),
      ),
    ),
    );
  }

  // ========== SCORING A STELLE ==========

  Widget _buildScoring(
    PromptGenerato prompt,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        children: [
          // Punteggio globale con stelle
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...List.generate(5, (i) {
                final valore = prompt.punteggioGlobale - i;
                return Icon(
                  valore >= 1
                      ? Icons.star_rounded
                      : valore >= 0.5
                          ? Icons.star_half_rounded
                          : Icons.star_outline_rounded,
                  color: colorScheme.primary,
                  size: 28,
                );
              }),
              const SizedBox(width: 10),
              Text(
                '${prompt.punteggioGlobale}/5',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Breakdown per criterio
          ...prompt.punteggiCriteri.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: entry.value / 5,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        color: colorScheme.primary,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${entry.value}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ========== TOGGLE VISTA ==========

  Widget _buildToggleVista(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleOpzione(
            etichetta: AppLocalizations.of(context)!.postGenViewSimple,
            icona: Icons.subject_rounded,
            selezionato: !_vistaStrutturata,
            colorScheme: colorScheme,
            onTap: () => setState(() {
              _vistaStrutturata = false;
              _sezioneInModifica = -1;
            }),
          ),
          _buildToggleOpzione(
            etichetta: AppLocalizations.of(context)!.postGenViewStructured,
            icona: Icons.view_agenda_outlined,
            selezionato: _vistaStrutturata,
            colorScheme: colorScheme,
            onTap: () => setState(() => _vistaStrutturata = true),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOpzione({
    required String etichetta,
    required IconData icona,
    required bool selezionato,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selezionato ? colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selezionato
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icona,
                size: 16,
                color: selezionato
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                etichetta,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selezionato ? FontWeight.w600 : FontWeight.w400,
                  color: selezionato
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========== HELPER SCORING SEZIONE ==========

  /// Calcola un punteggio locale (0.5-5.0) per una singola sezione
  /// basandosi su lunghezza, specificità, struttura e dettaglio.
  double _calcolaPunteggioSezione(SezionePrompt sezione) {
    final c = sezione.contenuto;
    if (c.isEmpty) return 0.0;
    double score = 1.5;
    if (c.length > 30) score += 0.5;
    if (c.length > 80) score += 0.5;
    if (c.length > 150) score += 0.5;
    if (c.length > 300) score += 0.5;
    if (RegExp(r'\d').hasMatch(c)) score += 0.3;
    if (c.contains('\n')) score += 0.2;
    if (c.split(' ').length > 20) score += 0.3;
    if (c.length < 15) score -= 1.0;
    return double.parse(score.clamp(0.5, 5.0).toStringAsFixed(1));
  }

  /// Restituisce un suggerimento testuale per migliorare una sezione debole.
  /// null se la sezione è già buona (punteggio >= 4.0).
  String? _suggerimentoPerSezione(SezionePrompt sezione, double punteggio) {
    if (punteggio >= 4.0) return null;
    final c = sezione.contenuto;
    final titolo = sezione.titolo.toLowerCase();
    if (c.length < 30) return AppLocalizations.of(context)!.postGenHintTooShort;
    if (!RegExp(r'\d').hasMatch(c) && (titolo.contains('vincol') || titolo.contains('formato'))) {
      return AppLocalizations.of(context)!.postGenHintAddNumbers;
    }
    if (!c.contains('\n') && c.length > 100) {
      return AppLocalizations.of(context)!.postGenHintBreakIntoBullets;
    }
    if (c.split(' ').length < 15) return AppLocalizations.of(context)!.postGenHintExpandDetails;
    if (punteggio < 3.0) return AppLocalizations.of(context)!.postGenHintWeakSection;
    return AppLocalizations.of(context)!.postGenHintBeMoreSpecific;
  }

  /// Avvia il miglioramento AI di una sezione e mostra l'anteprima prima/dopo
  Future<void> _miglioraSezione(int indice) async {
    setState(() => _sezioneMigliorandosi = indice);
    final provider = context.read<PromptGeneratoProvider>();
    final risultato = await provider.miglioraSezione(indice);
    if (!mounted) return;
    setState(() => _sezioneMigliorandosi = -1);
    if (risultato != null) {
      _mostraAnteprimaMiglioramento(indice, risultato);
    } else {
      _mostraConferma(Icons.error_outline, AppLocalizations.of(context)!.postGenErrorImproveSection);
    }
  }

  /// Bottom sheet con anteprima prima/dopo del miglioramento AI per una sezione
  void _mostraAnteprimaMiglioramento(int indice, String testoMigliorato) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<PromptGeneratoProvider>();
    final sezione = provider.prompt!.sezioni[indice];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildManiglia(colorScheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.postGenImprovementTitle(sezione.titolo),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenBefore, Colors.orange),
                      const SizedBox(height: 8),
                      _buildBoxTesto(sezione.contenuto, colorScheme, isDark),
                      const SizedBox(height: 16),
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenAfterImproved, colorScheme.primary),
                      const SizedBox(height: 8),
                      _buildBoxTesto(testoMigliorato, colorScheme, isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(AppLocalizations.of(context)!.postGenButtonDiscard),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          provider.aggiornaSezione(indice, testoMigliorato);
                          Navigator.of(ctx).pop();
                          _mostraConferma(Icons.check_circle, AppLocalizations.of(context)!.postGenSuccessSectionImproved);
                        },
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: Text(AppLocalizations.of(context)!.postGenButtonApply),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mostra un bottom sheet con il template predefinito per il tipo di sezione
  void _mostraTemplate(int indice) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<PromptGeneratoProvider>();
    final sezione = provider.prompt!.sezioni[indice];
    final template = _templatePerSezione[sezione.titolo];
    if (template == null) {
      _mostraConferma(Icons.info_outline, AppLocalizations.of(context)!.postGenInfoNoTemplate);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildManiglia(colorScheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.dashboard_customize_outlined,
                        color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.postGenTemplateTitle(sezione.titolo),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(
                  AppLocalizations.of(context)!.postGenTemplateInstruction,
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenCurrent, Colors.orange),
                      const SizedBox(height: 8),
                      _buildBoxTesto(sezione.contenuto, colorScheme, isDark),
                      const SizedBox(height: 16),
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenTemplateLabelAfter, colorScheme.primary),
                      const SizedBox(height: 8),
                      _buildBoxTesto(template, colorScheme, isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(AppLocalizations.of(context)!.postGenButtonClose),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          provider.aggiornaSezione(indice, template);
                          Navigator.of(ctx).pop();
                          _mostraConferma(Icons.check_circle, AppLocalizations.of(context)!.postGenSuccessTemplateApplied);
                        },
                        icon: const Icon(Icons.content_paste_rounded, size: 20),
                        label: Text(AppLocalizations.of(context)!.postGenButtonUseTemplate),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Mostra un'anteprima del prompt ricomposto con opzione di copiare
  void _mostraAnteprimaRicomponi(PromptGenerato prompt) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildManiglia(colorScheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(Icons.preview_rounded, color: colorScheme.primary, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.postGenFullPromptPreview,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: SelectableText(
                      prompt.testoCompleto,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.6,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: prompt.testoCompleto),
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop();
                      if (mounted) {
                        _mostraConferma(Icons.check_circle, AppLocalizations.of(context)!.copiedToClipboard);
                      }
                    },
                    icon: const Icon(Icons.copy_rounded, size: 20),
                    label: Text(AppLocalizations.of(context)!.postGenCopyFullPrompt),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========== VISTA SEMPLICE ==========
  //
  // Mostra il prompt come testo unico, pulito, non modificabile,
  // con un grande bottone "Copia prompt" in evidenza.
  // È la vista "ready to use" — l'utente copia e incolla nella sua AI.

  Widget _buildVistaSemplice(
    PromptGenerato prompt,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Etichetta superiore: chiarisce che è "pronto da copiare"
        Row(
          children: [
            Icon(
              Icons.lock_outline,
              size: 14,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              AppLocalizations.of(context)!.postGenReadOnly,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Box con il testo del prompt (non modificabile)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: SelectableText(
            prompt.testoCompleto,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
          ),
        ),
        const SizedBox(height: 16),

        // Grande bottone "Copia prompt" in evidenza
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 22),
            label: Text(
              AppLocalizations.of(context)!.postGenButtonCopyPrompt,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: prompt.testoCompleto),
              );
              if (mounted) {
                _mostraConferma(
                  Icons.check_circle,
                  AppLocalizations.of(context)!.copiedToClipboard,
                );
              }
            },
          ),
        ),
      ],
    );
  }

  // ========== VISTA STRUTTURATA ==========
  //
  // Mostra il prompt suddiviso nelle sue sezioni (Ruolo, Contesto,
  // Istruzioni, Formato output, Vincoli, ecc.), ognuna modificabile
  // separatamente e collassabile. Il prompt finale viene ricomposto
  // dalle sezioni modificate.

  Widget _buildVistaStrutturata(
    PromptGenerato prompt,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Filtra solo le sezioni non vuote (indice originale preservato)
    final sezioniConIndice = <MapEntry<int, SezionePrompt>>[];
    for (var i = 0; i < prompt.sezioni.length; i++) {
      if (prompt.sezioni[i].contenuto.isNotEmpty) {
        sezioniConIndice.add(MapEntry(i, prompt.sezioni[i]));
      }
    }

    // Calcola la percentuale di miglioramento rispetto al testo originale
    final provider = context.read<PromptGeneratoProvider>();
    final testoOriginale = provider.testoOriginale;
    final testoAttuale = prompt.testoCompleto;
    int? percentualeMiglioramento;
    if (testoOriginale != null &&
        testoOriginale.isNotEmpty &&
        testoAttuale != testoOriginale) {
      final diff = testoAttuale.length - testoOriginale.length;
      percentualeMiglioramento =
          ((diff / testoOriginale.length) * 100).round().abs();
      if (percentualeMiglioramento == 0) percentualeMiglioramento = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Banner miglioramento % (se il prompt è stato modificato)
        if (percentualeMiglioramento != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up_rounded,
                    size: 18, color: Color(0xFF10B981)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.postGenImprovementBanner(percentualeMiglioramento.toString()),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Etichetta superiore
        Row(
          children: [
            Icon(Icons.edit_note_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.postGenSectionsLabel(sezioniConIndice.length.toString()),
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Card di ogni sezione con punteggio e suggerimenti
        ...List.generate(prompt.sezioni.length, (indice) {
          final sezione = prompt.sezioni[indice];
          if (sezione.contenuto.isEmpty) return const SizedBox.shrink();

          final inModifica = _sezioneInModifica == indice;
          final coloreSezione = Color(sezione.colore);
          final punteggio = _calcolaPunteggioSezione(sezione);
          final suggerimento = _suggerimentoPerSezione(sezione, punteggio);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CardSezione(
              sezione: sezione,
              coloreSezione: coloreSezione,
              isDark: isDark,
              colorScheme: colorScheme,
              inModifica: inModifica,
              icona: _getIcona(sezione.icona),
              punteggioSezione: punteggio,
              suggerimentoDebolezza: suggerimento,
              staMigliorando: _sezioneMigliorandosi == indice,
              onMigliora: () => _miglioraSezione(indice),
              onTemplate: _templatePerSezione.containsKey(sezione.titolo)
                  ? () => _mostraTemplate(indice)
                  : null,
              onTapModifica: () {
                setState(() {
                  if (inModifica) {
                    _sezioneInModifica = -1;
                  } else {
                    _sezioneInModifica = indice;
                    _editController.text = sezione.contenuto;
                  }
                });
              },
              editController: _editController,
              onSalva: () {
                context.read<PromptGeneratoProvider>().aggiornaSezione(
                      indice,
                      _editController.text,
                    );
                setState(() => _sezioneInModifica = -1);
              },
              onAnnulla: () {
                setState(() => _sezioneInModifica = -1);
              },
            ),
          );
        }),

        // Bottone "Ricomponi e copia" — anteprima del testo finale e copia
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: const Icon(Icons.content_copy_rounded, size: 20),
            label: Text(
              AppLocalizations.of(context)!.postGenButtonRecomposeAndCopy,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => _mostraAnteprimaRicomponi(prompt),
          ),
        ),
      ],
    );
  }

  // ========== SUGGERIMENTI ==========

  Widget _buildSuggerimenti(
    PromptGenerato prompt,
    ColorScheme colorScheme,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: prompt.suggerimenti.map((suggerimento) {
        return ActionChip(
          avatar: Icon(
            _getIcona(suggerimento.icona),
            size: 16,
            color: colorScheme.primary,
          ),
          label: Text(
            suggerimento.etichetta,
            style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
          ),
          backgroundColor: colorScheme.surfaceContainerLow,
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          onPressed: () => _mostraAnteprimaSuggerimento(
            suggerimento,
            colorScheme,
          ),
        );
      }).toList(),
    );
  }

  /// Bottom sheet con anteprima prima/dopo per un suggerimento
  void _mostraAnteprimaSuggerimento(
    SuggerimentoMiglioramento suggerimento,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildManiglia(colorScheme),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  children: [
                    Icon(
                      _getIcona(suggerimento.icona),
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      suggerimento.etichetta,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                child: Text(
                  suggerimento.descrizione,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenBefore, Colors.orange),
                      const SizedBox(height: 8),
                      _buildBoxTesto(suggerimento.testoPrima, colorScheme, isDark),
                      const SizedBox(height: 16),
                      _buildEtichettaPrimaDopo(AppLocalizations.of(context)!.postGenAfter, colorScheme.primary),
                      const SizedBox(height: 8),
                      _buildBoxTesto(suggerimento.testoDopo, colorScheme, isDark),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context
                          .read<PromptGeneratoProvider>()
                          .applicaSuggerimento(suggerimento);
                      Navigator.of(ctx).pop();
                    },
                    icon: const Icon(Icons.check_rounded, size: 20),
                    label: Text(AppLocalizations.of(context)!.postGenButtonApplyImprovement),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ========== BARRA AZIONI ==========

  Widget _buildBarraAzioni(
    PromptGenerato prompt,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final cronologia = context.watch<CronologiaProvider>();
    final giaSalvato = cronologia.isGiaSalvato(prompt);

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
      child: Row(
        children: [
          // Bottone "Copia"
          Expanded(
            child: _buildBottoneAzione(
              icona: Icons.copy_rounded,
              etichetta: AppLocalizations.of(context)!.postGenButtonCopy,
              colorScheme: colorScheme,
              isPrimario: true,
              onPressed: () async {
                try {
                  await ExportService.copiaTestoNegliAppunti(prompt);
                  if (mounted) {
                    _mostraConferma(
                      Icons.check_circle,
                      AppLocalizations.of(context)!.copiedToClipboard,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    _mostraConferma(
                      Icons.error_outline,
                      AppLocalizations.of(context)!.postGenErrorCopy,
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(width: 10),
          // Bottone "Esporta" — apre il bottom sheet export
          Expanded(
            child: _buildBottoneAzione(
              icona: Icons.ios_share_rounded,
              etichetta: AppLocalizations.of(context)!.postGenButtonExport,
              colorScheme: colorScheme,
              isPrimario: false,
              onPressed: () => _mostraExportSheet(prompt, colorScheme),
            ),
          ),
          const SizedBox(width: 10),
          // Bottone "Pubblica" — pubblica nella community
          Expanded(
            child: _buildBottoneAzione(
              icona: Icons.public_outlined,
              etichetta: AppLocalizations.of(context)!.postGenButtonPublish,
              colorScheme: colorScheme,
              isPrimario: false,
              onPressed: () => _mostraPubblicaSheet(prompt, colorScheme),
            ),
          ),
          const SizedBox(width: 10),
          // Bottone "Salva" — salva nella cronologia in memoria
          Expanded(
            child: _buildBottoneAzione(
              icona: giaSalvato
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_outline_rounded,
              etichetta: giaSalvato ? AppLocalizations.of(context)!.postGenButtonSaved : AppLocalizations.of(context)!.postGenButtonSave,
              colorScheme: colorScheme,
              isPrimario: false,
              onPressed: giaSalvato
                  ? null
                  : () => _salvaPrompt(prompt, colorScheme),
            ),
          ),
        ],
      ),
    );
  }

  /// Salva il prompt nella cronologia
  void _salvaPrompt(PromptGenerato prompt, ColorScheme colorScheme) {
    final sessione = context.read<SessioneProvider>().sessione;
    context.read<CronologiaProvider>().salvaPrompt(
          prompt: prompt,
          categoria: sessione.categoria?.nome ?? 'Generico',
          fraseIniziale: sessione.fraseIniziale,
          aiDestinazione: _aiSelezionata,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.postGenSuccessPromptSaved),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ========== BOTTOM SHEET PUBBLICA ==========

  /// Mostra il bottom sheet per pubblicare il prompt nella community
  void _mostraPubblicaSheet(PromptGenerato prompt, ColorScheme colorScheme) {
    Visibilita visibilitaSelezionata = Visibilita.pubblico;
    final titoloController = TextEditingController();
    final descrizioneController = TextEditingController();

    // Pre-compila titolo dalla sessione
    final sessione = context.read<SessioneProvider>().sessione;
    titoloController.text = sessione.categoria != null ? localizeCategory(sessione.categoria!.nome, context) : AppLocalizations.of(context)!.postGenMyPromptDefault;
    descrizioneController.text = sessione.fraseIniziale;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              padding: EdgeInsets.fromLTRB(
                  24, 20, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Maniglia
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Titolo
                    Text(
                      AppLocalizations.of(context)!.postGenPublishSheetTitle,
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 20),

                    // Campo titolo
                    TextField(
                      controller: titoloController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.postGenPromptTitleLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Campo descrizione
                    TextField(
                      controller: descrizioneController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.postGenShortDescriptionLabel,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Visibilità
                    Text(
                      AppLocalizations.of(context)!.postGenVisibilityLabel,
                      style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 10),

                    // Opzioni visibilità
                    _buildOpzioneVisibilita(
                      ctx,
                      icona: Icons.lock_outline,
                      titolo: AppLocalizations.of(context)!.postGenVisibilityPrivate,
                      descrizione: AppLocalizations.of(context)!.postGenVisibilityPrivateDesc,
                      visibilita: Visibilita.privato,
                      selezionata: visibilitaSelezionata,
                      colorScheme: colorScheme,
                      onTap: () => setSheetState(
                          () => visibilitaSelezionata = Visibilita.privato),
                    ),
                    const SizedBox(height: 8),
                    _buildOpzioneVisibilita(
                      ctx,
                      icona: Icons.link,
                      titolo: AppLocalizations.of(context)!.postGenVisibilityLinkOnly,
                      descrizione: AppLocalizations.of(context)!.postGenVisibilityLinkOnlyDesc,
                      visibilita: Visibilita.soloLink,
                      selezionata: visibilitaSelezionata,
                      colorScheme: colorScheme,
                      onTap: () => setSheetState(
                          () => visibilitaSelezionata = Visibilita.soloLink),
                    ),
                    const SizedBox(height: 8),
                    _buildOpzioneVisibilita(
                      ctx,
                      icona: Icons.public,
                      titolo: AppLocalizations.of(context)!.postGenVisibilityPublic,
                      descrizione:
                          AppLocalizations.of(context)!.postGenVisibilityPublicDesc,
                      visibilita: Visibilita.pubblico,
                      selezionata: visibilitaSelezionata,
                      colorScheme: colorScheme,
                      onTap: () => setSheetState(
                          () => visibilitaSelezionata = Visibilita.pubblico),
                    ),
                    const SizedBox(height: 20),

                    // Bottone pubblica
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          if (titoloController.text.trim().isEmpty) return;
                          context.read<CommunityProvider>().pubblicaPrompt(
                                titolo: titoloController.text.trim(),
                                descrizione:
                                    descrizioneController.text.trim(),
                                categoria:
                                    sessione.categoria?.nome ?? 'Generico',
                                sezioni: prompt.sezioni,
                                punteggio: prompt.punteggioGlobale,
                                visibilita: visibilitaSelezionata,
                              );
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Colors.white, size: 18),
                                  const SizedBox(width: 8),
                                  Text(visibilitaSelezionata ==
                                          Visibilita.pubblico
                                      ? AppLocalizations.of(context)!.postGenSuccessPromptPublished
                                      : AppLocalizations.of(context)!.postGenSuccessPromptSaved),
                                ],
                              ),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.publish),
                        label: Text(AppLocalizations.of(context)!.postGenPublishButton),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Opzione di visibilità nel bottom sheet di pubblicazione
  Widget _buildOpzioneVisibilita(
    BuildContext context, {
    required IconData icona,
    required String titolo,
    required String descrizione,
    required Visibilita visibilita,
    required Visibilita selezionata,
    required ColorScheme colorScheme,
    required VoidCallback onTap,
  }) {
    final isSelezionata = visibilita == selezionata;
    return Container(
      decoration: BoxDecoration(
        color: isSelezionata
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelezionata
              ? colorScheme.primary.withValues(alpha: 0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(
                  icona,
                  size: 22,
                  color: isSelezionata
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titolo,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isSelezionata
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        descrizione,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelezionata)
                  Icon(Icons.check_circle,
                      size: 20, color: colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========== BOTTOM SHEET EXPORT ==========

  /// Mostra il bottom sheet con le opzioni di export e il selettore AI
  void _mostraExportSheet(PromptGenerato prompt, ColorScheme colorScheme) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildManiglia(colorScheme),
                  const SizedBox(height: 12),

                  // Titolo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.postGenExportSheetTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // --- Selettore AI di destinazione ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.postGenOptimizeForAI,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildSelettoreAi(
                          colorScheme,
                          isDark,
                          (ai) => setSheetState(() => _aiSelezionata = ai),
                        ),
                      ],
                    ),
                  ),

                  // Messaggio ottimizzazione
                  if (_aiSelezionata != null && _aiSelezionata != 'Generico')
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppLocalizations.of(context)!.postGenOptimizedFor(localizeAIOption(_aiSelezionata!, context)),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // --- Opzioni di export ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(context)!.postGenExportMethodLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Confronta risposte AI — funzionalità killer
                        _buildOpzioneExport(
                          icona: Icons.compare_arrows_rounded,
                          etichetta: AppLocalizations.of(context)!.postGenExportCompareAI,
                          descrizione: AppLocalizations.of(context)!.postGenExportCompareAIDesc,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _mostraSelezionaAIConfronto(prompt, colorScheme);
                          },
                        ),
                        const SizedBox(height: 8),

                        // Copia negli appunti
                        _buildOpzioneExport(
                          icona: Icons.copy_rounded,
                          etichetta: AppLocalizations.of(context)!.postGenExportCopyClipboard,
                          descrizione: AppLocalizations.of(context)!.postGenExportCopyClipboardDesc,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            try {
                              await ExportService.copiaTestoNegliAppunti(prompt);
                              if (mounted) {
                                _mostraConferma(
                                  Icons.check_circle,
                                  AppLocalizations.of(context)!.copiedToClipboard,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                _mostraConferma(
                                  Icons.error_outline,
                                  AppLocalizations.of(context)!.postGenErrorCopy,
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        // Condividi come testo
                        _buildOpzioneExport(
                          icona: Icons.share_rounded,
                          etichetta: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportCopyFullTextWeb
                              : AppLocalizations.of(context)!.postGenExportShareAsTextMobile,
                          descrizione: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportCopyClipboardWebDesc
                              : AppLocalizations.of(context)!.postGenExportShareAppsList,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            try {
                              await ExportService.condividiTesto(prompt);
                              if (mounted) {
                                _mostraConferma(
                                  Icons.check_circle,
                                  AppLocalizations.of(context)!.copiedToClipboard,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                _mostraConferma(
                                  Icons.error_outline,
                                  AppLocalizations.of(context)!.postGenErrorShare,
                                );
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),

                        // Esporta come PDF
                        _buildOpzioneExport(
                          icona: Icons.picture_as_pdf_rounded,
                          etichetta: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportDownloadPDFWeb
                              : AppLocalizations.of(context)!.postGenExportPDFMobile,
                          descrizione: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportPDFWebDesc
                              : AppLocalizations.of(context)!.postGenExportPDFMobileDesc,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _esportaConFeedback(
                              () => ExportService.esportaPdf(
                                prompt,
                                nomeAiDestinazione: _aiSelezionata,
                              ),
                              messaggioSuccesso: kIsWeb
                                  ? AppLocalizations.of(context)!.postGenSuccessPDFDownloaded
                                  : null,
                            );
                          },
                        ),
                        const SizedBox(height: 8),

                        // Esporta come TXT
                        _buildOpzioneExport(
                          icona: Icons.description_outlined,
                          etichetta: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportDownloadTXTWeb
                              : AppLocalizations.of(context)!.postGenExportTXTMobile,
                          descrizione: kIsWeb
                              ? AppLocalizations.of(context)!.postGenExportTXTWebDesc
                              : AppLocalizations.of(context)!.postGenExportTXTMobileDesc,
                          colorScheme: colorScheme,
                          isDark: isDark,
                          onTap: () async {
                            Navigator.of(ctx).pop();
                            await _esportaConFeedback(
                              () => ExportService.esportaTxt(
                                prompt,
                                nomeAiDestinazione: _aiSelezionata,
                              ),
                              messaggioSuccesso: kIsWeb
                                  ? AppLocalizations.of(context)!.postGenSuccessTXTDownloaded
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Mostra il bottom sheet per selezionare le AI da confrontare
  void _mostraSelezionaAIConfronto(
    PromptGenerato prompt,
    ColorScheme colorScheme,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confrontoProvider = context.read<ConfrontoAIProvider>();
    final sessione = context.read<SessioneProvider>().sessione;
    final categoria = sessione.categoria?.nome ?? 'Scrittura';

    // Pre-seleziona le AI suggerite per la categoria
    final suggerite = confrontoProvider.suggerisciAI(categoria);
    confrontoProvider.preseleziona(suggerite);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            // Legge lo stato aggiornato dal provider
            final aiSelezionate = confrontoProvider.aiSelezionate;

            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildManiglia(colorScheme),
                  const SizedBox(height: 12),

                  // Titolo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          color: colorScheme.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.postGenAICompareSheetTitle,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Sottotitolo
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      AppLocalizations.of(context)!.postGenAICompareSubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Badge suggerite
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome,
                            size: 16, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          AppLocalizations.of(context)!.postGenSuggestedForCategory(localizeCategory(categoria, context)),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lista AI con checkbox
                  ...ConfrontoAIProvider.aiDisponibili.map((ai) {
                    final selezionata = aiSelezionate.contains(ai.nome);
                    final suggerita = suggerite.any((s) => s.nome == ai.nome);

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 3),
                      child: Container(
                        decoration: BoxDecoration(
                          color: selezionata
                              ? ai.colore.withValues(alpha: 0.06)
                              : colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: selezionata
                                ? ai.colore
                                : Colors.transparent,
                            width: selezionata ? 1.5 : 0,
                          ),
                        ),
                        child: CheckboxListTile(
                          value: selezionata,
                          onChanged: (_) {
                            confrontoProvider.toggleAI(ai.nome);
                            setSheetState(() {});
                          },
                          secondary: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: ai.colore.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(ai.icona, color: ai.colore, size: 22),
                          ),
                          title: Row(
                            children: [
                              Text(
                                ai.nome,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              if (suggerita) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    AppLocalizations.of(context)!.postGenSuggestedBadge,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text(
                            AppLocalizations.of(context)!.postGenStrongIn(ai.categorieForti.map((c) => localizeCategory(c, context)).join(", ")),
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          activeColor: ai.colore,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          controlAffinity: ListTileControlAffinity.trailing,
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),

                  // Bottone "Confronta"
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: aiSelezionate.length >= 2
                            ? () {
                                Navigator.of(ctx).pop();
                                _avviaConfronto(prompt, categoria);
                              }
                            : null,
                        icon: const Icon(Icons.compare_arrows, size: 20),
                        label: Text(
                          aiSelezionate.length >= 2
                              ? AppLocalizations.of(context)!.postGenCompareCount(aiSelezionate.length.toString())
                              : AppLocalizations.of(context)!.postGenSelectAtLeast2,
                        ),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Avvia il confronto navigando alla schermata dedicata
  void _avviaConfronto(PromptGenerato prompt, String categoria) {
    final confrontoProvider = context.read<ConfrontoAIProvider>();

    // Avvia il confronto (simulato)
    confrontoProvider.avviaConfronto(prompt, categoria);

    // Naviga alla schermata di confronto
    Navigator.of(context).pushNamed(AppRoutes.confrontoAI);
  }

  /// Selettore AI — griglia orizzontale con icone
  Widget _buildSelettoreAi(
    ColorScheme colorScheme,
    bool isDark,
    ValueChanged<String> onSelect,
  ) {
    // Lista delle AI disponibili con icone Material
    final listaAi = [
      _AiOption('ChatGPT', Icons.chat_bubble_outline, const Color(0xFF10A37F)),
      _AiOption('Claude', Icons.auto_awesome, const Color(0xFFD97706)),
      _AiOption('Gemini', Icons.diamond_outlined, const Color(0xFF4285F4)),
      _AiOption('Generico', Icons.tune, colorScheme.onSurfaceVariant),
    ];

    return Row(
      children: listaAi.map((ai) {
        final selezionato = _aiSelezionata == ai.nome;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(ai.nome),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selezionato
                    ? ai.colore.withValues(alpha: 0.1)
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selezionato ? ai.colore : Colors.transparent,
                  width: 1.5,
                ),
                boxShadow: [
                  if (!isDark && !selezionato)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    ai.icona,
                    size: 24,
                    color: selezionato
                        ? ai.colore
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    localizeAIOption(ai.nome, context),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight:
                          selezionato ? FontWeight.w600 : FontWeight.w400,
                      color: selezionato
                          ? ai.colore
                          : colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// Singola opzione nel bottom sheet export
  Widget _buildOpzioneExport({
    required IconData icona,
    required String etichetta,
    required String descrizione,
    required ColorScheme colorScheme,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icona, size: 20, color: colorScheme.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etichetta,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descrizione,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Esegue l'export con feedback di successo o errore
  Future<void> _esportaConFeedback(
    Future<void> Function() azione, {
    String? messaggioSuccesso,
  }) async {
    try {
      await azione();
      if (mounted && messaggioSuccesso != null) {
        _mostraConferma(Icons.check_circle, messaggioSuccesso);
      }
    } catch (e) {
      if (mounted) {
        _mostraConferma(Icons.error_outline, AppLocalizations.of(context)!.postGenErrorExport);
      }
    }
  }

  /// Mostra una snackbar di conferma con icona
  void _mostraConferma(IconData icona, String messaggio) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icona, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(messaggio)),
          ],
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ========== WIDGET HELPER ==========

  /// Maniglia del bottom sheet
  Widget _buildManiglia(ColorScheme colorScheme) {
    return Container(
      width: 36,
      height: 5,
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildEtichettaPrimaDopo(String testo, Color colore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        testo,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colore,
        ),
      ),
    );
  }

  Widget _buildBoxTesto(
    String testo,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Text(
        testo.isEmpty ? AppLocalizations.of(context)!.postGenEmptyPlaceholder : testo,
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: testo.isEmpty
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSurface,
          fontStyle: testo.isEmpty ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }

  Widget _buildBottoneAzione({
    required IconData icona,
    required String etichetta,
    required ColorScheme colorScheme,
    required bool isPrimario,
    required VoidCallback? onPressed,
  }) {
    if (isPrimario) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, size: 18),
            const SizedBox(width: 6),
            Text(etichetta, style: const TextStyle(fontSize: 14)),
          ],
        ),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icona, size: 18),
          const SizedBox(width: 6),
          Text(etichetta, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }
}

// ========== MODELLO AI OPTION ==========

/// Rappresenta un'opzione AI nel selettore
class _AiOption {
  final String nome;
  final IconData icona;
  final Color colore;
  const _AiOption(this.nome, this.icona, this.colore);
}

// ========== WIDGET CARD SEZIONE ==========

/// Card collassabile per una singola sezione del prompt nella vista strutturata.
/// Include: punteggio sezione, barra completezza, suggerimento debolezza,
/// bottoni azione (Migliora AI, Template, Modifica).
class _CardSezione extends StatefulWidget {
  final SezionePrompt sezione;
  final Color coloreSezione;
  final bool isDark;
  final ColorScheme colorScheme;
  final bool inModifica;
  final IconData icona;
  final double punteggioSezione;
  final String? suggerimentoDebolezza;
  final bool staMigliorando;
  final VoidCallback onMigliora;
  final VoidCallback? onTemplate;
  final VoidCallback onTapModifica;
  final TextEditingController editController;
  final VoidCallback onSalva;
  final VoidCallback onAnnulla;

  const _CardSezione({
    required this.sezione,
    required this.coloreSezione,
    required this.isDark,
    required this.colorScheme,
    required this.inModifica,
    required this.icona,
    required this.punteggioSezione,
    this.suggerimentoDebolezza,
    required this.staMigliorando,
    required this.onMigliora,
    this.onTemplate,
    required this.onTapModifica,
    required this.editController,
    required this.onSalva,
    required this.onAnnulla,
  });

  @override
  State<_CardSezione> createState() => _CardSezioneState();
}

class _CardSezioneState extends State<_CardSezione> {
  bool _espansa = true;

  /// Colore della barra di completezza basato sul punteggio
  Color _coloreCompletezza(double punteggio) {
    if (punteggio >= 4.0) return const Color(0xFF10B981); // verde
    if (punteggio >= 2.5) return const Color(0xFFF59E0B); // giallo/arancio
    return const Color(0xFFEF4444); // rosso
  }

  @override
  Widget build(BuildContext context) {
    final coloreBar = _coloreCompletezza(widget.punteggioSezione);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: widget.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: widget.inModifica
            ? Border.all(color: widget.colorScheme.primary, width: 1.5)
            : null,
        boxShadow: [
          if (!widget.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con icona, titolo, punteggio badge e freccia espandi
          InkWell(
            onTap: () => setState(() => _espansa = !_espansa),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: widget.coloreSezione.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      widget.icona,
                      size: 18,
                      color: widget.coloreSezione,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.sezione.titolo,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  // Badge punteggio sezione
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: coloreBar.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${widget.punteggioSezione}/5',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: coloreBar,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _espansa ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 20,
                      color: widget.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Barra di completezza colorata (verde/giallo/rosso)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: (widget.punteggioSezione / 5).clamp(0.0, 1.0),
                backgroundColor:
                    widget.colorScheme.surfaceContainerHighest,
                color: coloreBar,
                minHeight: 3,
              ),
            ),
          ),

          // Contenuto espandibile
          AnimatedCrossFade(
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Suggerimento debolezza (se presente)
                  if (widget.suggerimentoDebolezza != null &&
                      !widget.inModifica) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: coloreBar.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.tips_and_updates_outlined,
                              size: 15, color: coloreBar),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              widget.suggerimentoDebolezza!,
                              style: TextStyle(
                                fontSize: 12,
                                color: coloreBar,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Contenuto sezione o campo modifica
                  widget.inModifica
                      ? _buildCampoModifica()
                      : Text(
                          widget.sezione.contenuto,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: widget.colorScheme.onSurface,
                          ),
                        ),

                  // Loading miglioramento
                  if (widget.staMigliorando) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: widget.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.postGenImprovingWithAI,
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],

                  // Bottoni azione (solo se non in modifica e non in miglioramento)
                  if (!widget.inModifica && !widget.staMigliorando) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Bottone Migliora (AI)
                        Expanded(
                          child: _buildBottoneAzioneCard(
                            icona: Icons.auto_awesome,
                            etichetta: AppLocalizations.of(context)!.postGenButtonImprove,
                            colore: widget.colorScheme.primary,
                            onTap: widget.onMigliora,
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Bottone Template (se disponibile)
                        if (widget.onTemplate != null) ...[
                          Expanded(
                            child: _buildBottoneAzioneCard(
                              icona: Icons.dashboard_customize_outlined,
                              etichetta: AppLocalizations.of(context)!.postGenButtonTemplate,
                              colore: widget.colorScheme.onSurfaceVariant,
                              onTap: widget.onTemplate!,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Bottone Modifica
                        Expanded(
                          child: _buildBottoneAzioneCard(
                            icona: Icons.edit_outlined,
                            etichetta: AppLocalizations.of(context)!.postGenButtonEdit,
                            colore: widget.colorScheme.onSurfaceVariant,
                            onTap: widget.onTapModifica,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _espansa
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  /// Bottone azione piccolo sotto la sezione
  Widget _buildBottoneAzioneCard({
    required IconData icona,
    required String etichetta,
    required Color colore,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: colore.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icona, size: 14, color: colore),
            const SizedBox(width: 4),
            Text(
              etichetta,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colore,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoModifica() {
    return Column(
      children: [
        TextField(
          controller: widget.editController,
          maxLines: null,
          minLines: 3,
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: widget.colorScheme.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: widget.colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.colorScheme.primary,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.onAnnulla,
              child: Text(
                AppLocalizations.of(context)!.postGenButtonCancel,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: widget.onSalva,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
              ),
              child: Text(AppLocalizations.of(context)!.postGenButtonSave, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
      ],
    );
  }
}
