import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/models/confronto_ai.dart';
import 'package:ideai/providers/confronto_ai_provider.dart';
import 'package:ideai/providers/cronologia_provider.dart';
import 'package:ideai/providers/sessione_provider.dart';

/// Schermata di confronto risposte multi-AI.
/// Mostra le risposte delle AI in card swipabili orizzontalmente
/// con punteggi, badge "Migliore" e azioni di copia/salvataggio.
class ConfrontoAIScreen extends StatefulWidget {
  const ConfrontoAIScreen({super.key});

  @override
  State<ConfrontoAIScreen> createState() => _ConfrontoAIScreenState();
}

class _ConfrontoAIScreenState extends State<ConfrontoAIScreen> {
  // Controller per il PageView delle card
  late final PageController _pageController;

  // Indice della card attualmente visibile
  int _paginaCorrente = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<ConfrontoAIProvider>();

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiComparisonAppBar),
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
        child: provider.staCaricando
            ? _buildCaricamento(colorScheme)
            : provider.confronto != null
                ? _buildRisultati(provider.confronto!, colorScheme, isDark)
                : _buildStatoVuoto(colorScheme),
      ),
    );
  }

  /// Animazione di caricamento — simula la chiamata alle AI
  Widget _buildCaricamento(ColorScheme colorScheme) {
    final provider = context.watch<ConfrontoAIProvider>();
    final aiSelezionate = provider.aiSelezionate;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icone delle AI che "lavorano"
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: aiSelezionate.map((nome) {
              final ai = ConfrontoAIProvider.aiDisponibili
                  .firstWhere((a) => a.nome == nome);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildIconaAIAnimata(ai, colorScheme),
              );
            }).toList(),
          ),
          const SizedBox(height: 32),

          // Progress indicator
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              borderRadius: BorderRadius.circular(4),
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            AppLocalizations.of(context)!.aiComparisonSendingPrompt(aiSelezionate.length.toString()),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.aiComparisonComparing,
            style: TextStyle(
              fontSize: 14,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Icona AI animata durante il caricamento
  Widget _buildIconaAIAnimata(InfoAI ai, ColorScheme colorScheme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.8, end: 1.0),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: child,
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ai.colore.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(
            color: ai.colore.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Icon(ai.icona, size: 28, color: ai.colore),
      ),
    );
  }

  /// Naviga alla pagina indicata con animazione
  void _vaiAPagina(int indice) {
    _pageController.animateToPage(
      indice,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  /// Contenuto principale: card swipabili con le risposte
  Widget _buildRisultati(
    ConfrontoAI confronto,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final totaleCard = confronto.risposte.length;

    return Column(
      children: [
        // Intestazione
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Row(
            children: [
              Icon(Icons.compare_arrows, color: colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)!.aiComparisonResponsesCompared(totaleCard.toString()),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),

        // Card swipabili con frecce di navigazione ai lati
        Expanded(
          child: Stack(
            alignment: Alignment.center,
            children: [
              // PageView con physics compatibile web
              PageView.builder(
                controller: _pageController,
                // ClampingScrollPhysics funziona meglio su web
                physics: const ClampingScrollPhysics(),
                itemCount: totaleCard,
                onPageChanged: (indice) {
                  setState(() => _paginaCorrente = indice);
                },
                itemBuilder: (context, indice) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: _buildCardRisposta(
                      confronto.risposte[indice],
                      colorScheme,
                      isDark,
                    ),
                  );
                },
              ),

              // Freccia sinistra
              if (_paginaCorrente > 0)
                Positioned(
                  left: 4,
                  child: _buildFreccia(
                    icona: Icons.chevron_left_rounded,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onPressed: () => _vaiAPagina(_paginaCorrente - 1),
                  ),
                ),

              // Freccia destra
              if (_paginaCorrente < totaleCard - 1)
                Positioned(
                  right: 4,
                  child: _buildFreccia(
                    icona: Icons.chevron_right_rounded,
                    colorScheme: colorScheme,
                    isDark: isDark,
                    onPressed: () => _vaiAPagina(_paginaCorrente + 1),
                  ),
                ),
            ],
          ),
        ),

        // Indicatore di posizione (pallini cliccabili)
        _buildIndicatorePosizione(totaleCard, colorScheme),

        // Barra azioni in basso
        _buildBarraAzioni(confronto, colorScheme, isDark),
      ],
    );
  }

  /// Bottone freccia per navigare tra le card — stile Apple traslucido
  Widget _buildFreccia({
    required IconData icona,
    required ColorScheme colorScheme,
    required bool isDark,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: isDark ? 0.15 : 0.06),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icona,
            size: 28,
            color: colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  /// Card di una singola risposta AI
  Widget _buildCardRisposta(
    RispostaAI risposta,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: risposta.isMigliore
              ? Colors.amber.shade600
              : isDark
                  ? colorScheme.outlineVariant
                  : Colors.transparent,
          width: risposta.isMigliore ? 2 : 0.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          // Bagliore dorato per la migliore
          if (risposta.isMigliore)
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.15),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Column(
        children: [
          // Header con nome AI + badge "Migliore"
          _buildHeaderCard(risposta, colorScheme, isDark),

          // Risposta scrollabile
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: SelectableText(
                risposta.risposta,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                      color: colorScheme.onSurface.withValues(alpha: 0.85),
                    ),
              ),
            ),
          ),

          // Punteggi in basso
          _buildPunteggiCard(risposta, colorScheme),
        ],
      ),
    );
  }

  /// Header della card con icona AI, nome e badge
  Widget _buildHeaderCard(
    RispostaAI risposta,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final ai = risposta.ai;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ai.colore.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          // Icona AI con colore
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: ai.colore.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(ai.icona, size: 22, color: ai.colore),
          ),
          const SizedBox(width: 12),

          // Nome AI
          Text(
            ai.nome,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
          const Spacer(),

          // Badge "Migliore" con bordo dorato
          if (risposta.isMigliore)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.amber.shade600,
                    Colors.amber.shade400,
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.amber.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.emoji_events, size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    AppLocalizations.of(context)!.aiComparisonBest,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Stelle punteggio
          if (!risposta.isMigliore) ...[
            Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade600),
            const SizedBox(width: 4),
            Text(
              risposta.punteggio.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Punteggi dettagliati in fondo alla card
  Widget _buildPunteggiCard(RispostaAI risposta, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Column(
        children: [
          // Riga: stelle grandi + punteggio
          if (risposta.isMigliore)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ...List.generate(5, (i) {
                    final piena = i < risposta.punteggio.floor();
                    final mezza = i == risposta.punteggio.floor() &&
                        risposta.punteggio % 1 >= 0.5;
                    return Icon(
                      piena
                          ? Icons.star_rounded
                          : mezza
                              ? Icons.star_half_rounded
                              : Icons.star_outline_rounded,
                      size: 22,
                      color: Colors.amber.shade600,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text(
                    risposta.punteggio.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),

          // Barre punteggi dettagliati
          ...risposta.punteggiDettaglio.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
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
                        color: risposta.ai.colore,
                        minHeight: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    entry.value.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurface,
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

  /// Indicatore di posizione — pallini cliccabili in basso
  Widget _buildIndicatorePosizione(int totale, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totale, (indice) {
          final attivo = indice == _paginaCorrente;
          return GestureDetector(
            onTap: () => _vaiAPagina(indice),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: attivo ? 24 : 8,
              height: 8,
              // Area di tap più generosa rispetto alla dimensione visiva
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              decoration: BoxDecoration(
                color: attivo
                    ? colorScheme.primary
                    : colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Barra azioni in basso
  Widget _buildBarraAzioni(
    ConfrontoAI confronto,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final rispostaCorrente = confronto.risposte[_paginaCorrente];

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
          // Copia risposta
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _copiaRisposta(rispostaCorrente),
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(AppLocalizations.of(context)!.aiComparisonCopy),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Apri nell'app
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _apriNellApp(rispostaCorrente),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(AppLocalizations.of(context)!.aiComparisonOpenInApp),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Salva confronto
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _salvaConfronto(confronto),
              icon: const Icon(Icons.bookmark_outline, size: 18),
              label: Text(AppLocalizations.of(context)!.aiComparisonSave),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Stato vuoto
  Widget _buildStatoVuoto(ColorScheme colorScheme) {
    return Center(
      child: Text(
        AppLocalizations.of(context)!.aiComparisonNoActive,
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
    );
  }

  // ===== AZIONI =====

  /// Copia la risposta corrente negli appunti
  void _copiaRisposta(RispostaAI risposta) {
    Clipboard.setData(ClipboardData(text: risposta.risposta));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.aiComparisonResponseCopied),
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

  /// Simula l'apertura dell'app AI corrispondente
  void _apriNellApp(RispostaAI risposta) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(risposta.ai.icona, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.aiComparisonOpeningApp),
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

  /// Salva il confronto nella cronologia
  void _salvaConfronto(ConfrontoAI confronto) {
    final sessione = context.read<SessioneProvider>().sessione;

    // Salva il prompt nella cronologia con nota del confronto
    context.read<CronologiaProvider>().salvaPrompt(
          prompt: confronto.prompt,
          categoria: sessione.categoria?.nome ?? 'Generico',
          fraseIniziale: sessione.fraseIniziale,
          aiDestinazione: confronto.risposte
              .map((r) => r.ai.nome)
              .join(', '),
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(AppLocalizations.of(context)!.aiComparisonSaved),
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
}
