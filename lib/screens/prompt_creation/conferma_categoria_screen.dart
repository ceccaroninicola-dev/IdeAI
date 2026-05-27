import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/utils/category_localizer.dart';
import 'package:ideai/providers/sessione_provider.dart';

/// Schermata di conferma categoria — seconda fase del flusso.
/// Design minimal stile Apple: card con ombre sottili, teal accento, padding generoso.
/// Include un selettore per il numero di domande (5, 10, 20).
class ConfermaCategoriaScreen extends StatefulWidget {
  const ConfermaCategoriaScreen({super.key});

  @override
  State<ConfermaCategoriaScreen> createState() =>
      _ConfermaCategoriaScreenState();
}

class _ConfermaCategoriaScreenState extends State<ConfermaCategoriaScreen> {
  /// Restituisce l'icona Material corrispondente al nome dell'icona della categoria
  IconData _getIcona(String nomeIcona) {
    switch (nomeIcona) {
      case 'code':
        return Icons.code;
      case 'image':
        return Icons.image;
      case 'edit_note':
        return Icons.edit_note;
      default:
        return Icons.auto_awesome;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sessione = context.watch<SessioneProvider>().sessione;
    final categoria = sessione.categoria;

    // Se la categoria non è stata rilevata, mostra il caricamento
    if (categoria == null) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: colorScheme.primary),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.confirmCategoryAppBar),
        actions: [
          // Bottone Home — torna alla Home cancellando lo stack
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: AppLocalizations.of(context)!.tooltipBackToHome,
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
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),

                      // Icona della categoria con sfondo teal morbido
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getIcona(categoria.icona),
                          size: 48,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Nome della categoria
                      Text(
                        localizeCategory(categoria.nome, context),
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),

                      // Sottocategoria (se presente) — chip teal
                      if (categoria.sottocategoria != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            categoria.sottocategoria!,
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(height: 28),

                      // Card riepilogo — stile Apple con ombra sottile
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20.0),
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
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Intestazione del riepilogo
                            Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: colorScheme.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)!.confirmCategoryUnderstoodTitle,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Testo del riepilogo
                            Text(
                              categoria.riepilogo,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 16),

                            // Frase originale dell'utente
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                  width: 0.5,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    AppLocalizations.of(context)!.confirmCategoryYourRequest,
                                    style: Theme.of(context).textTheme.labelSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '"${sessione.fraseIniziale}"',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Parole chiave rilevate
                      if (categoria.elementiChiave.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            AppLocalizations.of(context)!.confirmCategoryDetectedKeywords,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categoria.elementiChiave
                              .map((elemento) => Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      elemento,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Bottoni di azione in basso
              const SizedBox(height: 16),
              Row(
                children: [
                  // Bottone "Riformula" — outlined teal
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          Navigator.of(context).pushNamedAndRemoveUntil(
                            AppRoutes.home,
                            (route) => false,
                          );
                        }
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(AppLocalizations.of(context)!.confirmCategoryRephrase),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Bottone "Prosegui" — teal pieno
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        final provider = context.read<SessioneProvider>();
                        provider.confermCategoria();
                        Navigator.of(context).pushNamed(AppRoutes.domande);
                      },
                      icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(AppLocalizations.of(context)!.confirmCategoryContinue),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
