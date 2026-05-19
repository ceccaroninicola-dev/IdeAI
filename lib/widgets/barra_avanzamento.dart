import 'package:flutter/material.dart';
import 'package:ideai/l10n/app_localizations.dart';

/// Widget che mostra una barra di avanzamento adattiva.
/// Stile Apple minimal: teal come colore primario, animazioni fluide.
class BarraAvanzamento extends StatelessWidget {
  /// Percentuale di completamento (da 0.0 a 1.0)
  final double percentuale;

  /// Indice della domanda corrente (0-based)
  final int domandaCorrente;

  /// Numero totale di domande
  final int totaleDomande;

  /// Callback quando l'utente tocca un punto specifico della barra
  final ValueChanged<int>? onTapDomanda;

  const BarraAvanzamento({
    super.key,
    required this.percentuale,
    required this.domandaCorrente,
    required this.totaleDomande,
    this.onTapDomanda,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Riga con testo di stato e percentuale
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Indicatore domanda corrente
              Text(
                totaleDomande > 0
                    ? l10n.progressQuestionOf(
                        (domandaCorrente + 1).toString(),
                        totaleDomande.toString(),
                      )
                    : l10n.progressAnalysing,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              // Percentuale di completamento — teal
              Text(
                '${(percentuale * 100).round()}%',
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Barra di avanzamento — teal pieno, sfondo sottile
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // Sfondo della barra
                Container(
                  height: 6,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Riempimento animato — teal uniforme
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                  height: 6,
                  width: constraints.maxWidth * percentuale.clamp(0.0, 1.0),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                // Indicatori cliccabili per ogni domanda
                if (totaleDomande > 0)
                  SizedBox(
                    height: 6,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(totaleDomande, (indice) {
                        final completata = indice < domandaCorrente;
                        final corrente = indice == domandaCorrente;

                        return GestureDetector(
                          onTap: completata && onTapDomanda != null
                              ? () => onTapDomanda!(indice)
                              : null,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: completata
                                  ? colorScheme.primary
                                  : corrente
                                      ? colorScheme.primary
                                          .withValues(alpha: 0.3)
                                      : Colors.transparent,
                              border: corrente && !completata
                                  ? Border.all(
                                      color: colorScheme.primary,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
