import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/models/prompt_template.dart';
import 'package:ideai/models/prompt_generato.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/providers/sessione_provider.dart';

/// Schermata dettaglio di un template — mostra il prompt completo
/// in vista strutturata con azioni "Usa template" e "Personalizza".
class DettaglioTemplateScreen extends StatefulWidget {
  const DettaglioTemplateScreen({super.key});

  @override
  State<DettaglioTemplateScreen> createState() =>
      _DettaglioTemplateScreenState();
}

class _DettaglioTemplateScreenState extends State<DettaglioTemplateScreen> {
  // Toggle: true = vista strutturata, false = vista semplice
  bool _vistaStrutturata = true;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Ricevi il template dagli arguments della rotta
    final template =
        ModalRoute.of(context)!.settings.arguments as PromptTemplate;

    return Scaffold(
      appBar: AppBar(
        title: Text(template.titolo),
        actions: [
          // Bottone Home
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Torna alla Home',
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
            // Contenuto scrollabile
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Header con info template ---
                    _buildHeader(template, colorScheme),
                    const SizedBox(height: 20),

                    // --- Toggle vista semplice/strutturata ---
                    _buildToggleVista(colorScheme),
                    const SizedBox(height: 16),

                    // --- Contenuto del prompt ---
                    if (_vistaStrutturata)
                      _buildVistaStrutturata(template, colorScheme, isDark)
                    else
                      _buildVistaSemplice(template, colorScheme, isDark),
                  ],
                ),
              ),
            ),

            // --- Barra azioni in basso ---
            _buildBarraAzioni(template, colorScheme, isDark),
          ],
        ),
      ),
    );
  }

  /// Header con icona, categoria, stelle e utilizzi
  Widget _buildHeader(PromptTemplate template, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Descrizione
        Text(
          template.descrizione,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 14),

        // Riga: categoria + stelle + utilizzi
        Row(
          children: [
            // Chip categoria
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                template.categoria,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Stelle
            Icon(Icons.star_rounded, size: 18, color: Colors.amber.shade600),
            const SizedBox(width: 4),
            Text(
              template.popolarita.toStringAsFixed(1),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const Spacer(),

            // Utilizzi
            Icon(Icons.people_outline, size: 16,
                color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              '${template.utilizzi} utilizzi',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Toggle tra vista semplice e strutturata
  Widget _buildToggleVista(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Bottone "Strutturata"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _vistaStrutturata = true),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _vistaStrutturata
                      ? colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    if (_vistaStrutturata)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                      ),
                  ],
                ),
                child: Text(
                  'Strutturata',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _vistaStrutturata
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _vistaStrutturata
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          // Bottone "Semplice"
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _vistaStrutturata = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_vistaStrutturata
                      ? colorScheme.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: [
                    if (!_vistaStrutturata)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 4,
                      ),
                  ],
                ),
                child: Text(
                  'Semplice',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: !_vistaStrutturata
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: !_vistaStrutturata
                        ? colorScheme.onSurface
                        : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Vista strutturata — sezioni colorate ed espandibili
  Widget _buildVistaStrutturata(
    PromptTemplate template,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Column(
      children: template.sezioni.map((sezione) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCardSezione(sezione, colorScheme, isDark),
        );
      }).toList(),
    );
  }

  /// Card di una singola sezione — stile Apple con colore laterale
  Widget _buildCardSezione(
    SezionePrompt sezione,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final coloreSezione = Color(sezione.colore);

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: coloreSezione, width: 3),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          leading: Icon(
            _getIconaSezione(sezione.titolo),
            color: coloreSezione,
            size: 20,
          ),
          title: Text(
            sezione.titolo,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
              fontSize: 15,
            ),
          ),
          children: [
            Text(
              sezione.contenuto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withValues(alpha: 0.85),
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Vista semplice — testo continuo in un contenitore
  Widget _buildVistaSemplice(
    PromptTemplate template,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 1),
            ),
        ],
      ),
      child: SelectableText(
        template.testoCompleto,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: colorScheme.onSurface.withValues(alpha: 0.85),
            ),
      ),
    );
  }

  /// Barra azioni in basso — "Usa template" e "Personalizza"
  Widget _buildBarraAzioni(
    PromptTemplate template,
    ColorScheme colorScheme,
    bool isDark,
  ) {
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
          // Bottone "Personalizza" — avvia il flusso domande
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _personalizzaTemplate(template),
              icon: const Icon(Icons.tune, size: 18),
              label: const Text('Personalizza'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bottone "Usa template" — carica nella post-generazione
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: () => _usaTemplate(template),
              icon: const Icon(Icons.flash_on, size: 18),
              label: const Text('Usa questo template'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Carica il template nella schermata post-generazione
  void _usaTemplate(PromptTemplate template) {
    final promptProvider = context.read<PromptGeneratoProvider>();

    // Genera il prompt dal template
    promptProvider.caricaDaTemplate(template);

    // Naviga alla post-generazione
    Navigator.of(context).pushNamed(AppRoutes.postGenerazione);
  }

  /// Avvia il flusso domande con il template come base
  void _personalizzaTemplate(PromptTemplate template) {
    final sessioneProvider = context.read<SessioneProvider>();
    final lang = Localizations.localeOf(context).languageCode;

    // Avvia una sessione con la descrizione del template
    sessioneProvider.avviaSessione(
      '${template.titolo}: ${template.descrizione}',
      lang: lang,
    );

    // Naviga alla conferma categoria
    Navigator.of(context).pushNamed(AppRoutes.confermaCategoria);
  }

  /// Restituisce l'icona Material per il titolo della sezione
  IconData _getIconaSezione(String titolo) {
    switch (titolo) {
      case 'Ruolo':
        return Icons.person_outline;
      case 'Contesto':
        return Icons.info_outline;
      case 'Istruzioni':
        return Icons.list_alt;
      case 'Formato Output':
        return Icons.format_align_left;
      case 'Vincoli':
        return Icons.block;
      case 'Esempi':
        return Icons.lightbulb_outline;
      default:
        return Icons.article_outlined;
    }
  }
}
