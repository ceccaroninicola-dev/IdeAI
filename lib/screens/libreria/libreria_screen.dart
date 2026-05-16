import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/models/prompt_template.dart';
import 'package:ideai/providers/libreria_provider.dart';

/// Schermata Libreria — raccolta di template pronti all'uso.
/// Griglia di card con ricerca, filtri per categoria e sezione "Più popolari".
class LibreriaScreen extends StatefulWidget {
  const LibreriaScreen({super.key});

  @override
  State<LibreriaScreen> createState() => _LibreriaScreenState();
}

class _LibreriaScreenState extends State<LibreriaScreen> {
  final _ricercaController = TextEditingController();

  @override
  void dispose() {
    _ricercaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<LibreriaProvider>();
    final templateFiltrati = provider.templateFiltrati;
    final mostraPopolare = provider.categoriaSelezionata == 'Tutti' &&
        provider.testoRicerca.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.libreriaTitle),
        actions: [
          // Bottone Home
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
        child: Column(
          children: [
            // --- Barra di ricerca ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: TextField(
                controller: _ricercaController,
                onChanged: (testo) => provider.cercaTemplate(testo),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.libreriaSearchHint,
                  prefixIcon: Icon(
                    Icons.search,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  suffixIcon: _ricercaController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _ricercaController.clear();
                            provider.cercaTemplate('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
            ),

            // --- Chip filtro per categoria ---
            _buildChipCategorie(provider, colorScheme),

            // --- Contenuto principale ---
            Expanded(
              child: templateFiltrati.isEmpty
                  ? _buildStatoVuoto(colorScheme)
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        // Sezione "Più popolari" (solo senza filtri)
                        if (mostraPopolare) ...[
                          _buildTitoloSezione(AppLocalizations.of(context)!.libreriaMostPopular, Icons.star),
                          const SizedBox(height: 10),
                          _buildGrigliaPopolare(
                            provider.piuPopolari,
                            colorScheme,
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          _buildTitoloSezione(AppLocalizations.of(context)!.libreriaAllTemplates, Icons.apps),
                          const SizedBox(height: 10),
                        ],

                        // Griglia di tutti i template filtrati
                        _buildGrigliaTemplate(
                          templateFiltrati,
                          colorScheme,
                          isDark,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Chip orizzontali scrollabili per le categorie
  Widget _buildChipCategorie(
    LibreriaProvider provider,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        itemCount: LibreriaProvider.categorie.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, indice) {
          final categoria = LibreriaProvider.categorie[indice];
          final selezionata = provider.categoriaSelezionata == categoria;
          final icona = LibreriaProvider.iconeCategorie[categoria];

          return FilterChip(
            avatar: selezionata
                ? null
                : Icon(icona, size: 16, color: colorScheme.onSurfaceVariant),
            label: Text(categoria),
            selected: selezionata,
            showCheckmark: false,
            onSelected: (_) => provider.selezionaCategoria(categoria),
            selectedColor: colorScheme.primary.withValues(alpha: 0.15),
            backgroundColor: colorScheme.surfaceContainerLow,
            side: BorderSide(
              color: selezionata
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              width: selezionata ? 1.5 : 0.5,
            ),
            labelStyle: TextStyle(
              color: selezionata
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              fontWeight: selezionata ? FontWeight.w600 : FontWeight.normal,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );
        },
      ),
    );
  }

  /// Titolo di sezione con icona
  Widget _buildTitoloSezione(String testo, IconData icona) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icona, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          testo,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  /// Griglia orizzontale dei template più popolari
  Widget _buildGrigliaPopolare(
    List<PromptTemplate> templates,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: templates.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, indice) {
          return SizedBox(
            width: 220,
            child: _buildCardTemplate(
              templates[indice],
              colorScheme,
              isDark,
              compatta: true,
            ),
          );
        },
      ),
    );
  }

  /// Griglia verticale di template (2 colonne)
  Widget _buildGrigliaTemplate(
    List<PromptTemplate> templates,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, indice) {
        return _buildCardTemplate(
          templates[indice],
          colorScheme,
          isDark,
        );
      },
    );
  }

  /// Card di un singolo template — stile Apple minimal
  Widget _buildCardTemplate(
    PromptTemplate template,
    ColorScheme colorScheme,
    bool isDark, {
    bool compatta = false,
  }) {
    // Icona della categoria
    final iconaCategoria =
        LibreriaProvider.iconeCategorie[template.categoria] ?? Icons.article;

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Naviga al dettaglio del template
            Navigator.of(context).pushNamed(
              AppRoutes.dettaglioTemplate,
              arguments: template,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Riga superiore: icona categoria + stelle
                Row(
                  children: [
                    // Badge icona categoria
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        iconaCategoria,
                        size: 18,
                        color: colorScheme.primary,
                      ),
                    ),
                    const Spacer(),
                    // Stelle popolarità
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: Colors.amber.shade600,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          template.popolarita.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Titolo
                Text(
                  template.titolo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: compatta ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Descrizione
                Expanded(
                  child: Text(
                    template.descrizione,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                    maxLines: compatta ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Tag categoria + utilizzi
                Row(
                  children: [
                    // Chip categoria
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        template.categoria,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Numero utilizzi
                    Text(
                      AppLocalizations.of(context)!.libreriaUsesCount(_formatUtilizzi(template.utilizzi)),
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Stato vuoto quando non ci sono risultati
  Widget _buildStatoVuoto(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.libreriaNoResults,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.libreriaNoResultsHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }

  /// Formatta il numero di utilizzi (es. 1243 → "1.2K")
  String _formatUtilizzi(int n) {
    if (n >= 1000) {
      return '${(n / 1000).toStringAsFixed(1)}K';
    }
    return n.toString();
  }
}
