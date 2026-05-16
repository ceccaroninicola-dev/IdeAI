import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/providers/community_provider.dart';
import 'package:ideai/models/prompt_pubblico.dart';
import 'package:ideai/utils/category_localizer.dart';

/// Schermata Community / Esplora — mostra prompt trending, recenti, con ricerca e filtri.
/// Design Apple-minimal con teal come accento.
class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final community = Provider.of<CommunityProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.communityAppBarTitle),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),

            // === BARRA DI RICERCA ===
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => community.cercaPrompt(value),
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.communitySearchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            community.cercaPrompt('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // === FILTRI CATEGORIA ===
            SizedBox(
              height: 38,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: community.categorie.length,
                itemBuilder: (context, index) {
                  final cat = community.categorie[index];
                  final selezionata = cat == community.categoriaFiltro;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(localizeCategory(cat, context)),
                      selected: selezionata,
                      onSelected: (_) => community.filtraPerCategoria(cat),
                      selectedColor:
                          colorScheme.primary.withValues(alpha: 0.15),
                      checkmarkColor: colorScheme.primary,
                      labelStyle: TextStyle(
                        color: selezionata
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                        fontWeight: selezionata
                            ? FontWeight.w600
                            : FontWeight.normal,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: selezionata
                            ? colorScheme.primary.withValues(alpha: 0.3)
                            : colorScheme.outlineVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Se c'è ricerca attiva, mostra risultati filtrati
            if (community.testoRicerca.isNotEmpty ||
                community.categoriaFiltro != 'Tutti') ...[
              _buildSezioneHeader(context, AppLocalizations.of(context)!.communityResultsTitle, colorScheme),
              const SizedBox(height: 12),
              if (community.promptFiltrati.isEmpty)
                _buildEmptyState(context, colorScheme)
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: community.promptFiltrati.length,
                  itemBuilder: (context, index) {
                    return _buildPromptCard(
                      context,
                      community.promptFiltrati[index],
                      colorScheme,
                      isDark,
                    );
                  },
                ),
            ] else ...[
              // === TRENDING ===
              _buildSezioneHeader(context, AppLocalizations.of(context)!.communityTrending, colorScheme,
                  icona: Icons.local_fire_department, coloreIcona: Colors.orange),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: community.trending.take(6).length,
                  itemBuilder: (context, index) {
                    return _buildTrendingCard(
                      context,
                      community.trending[index],
                      colorScheme,
                      isDark,
                      index,
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // === PIÙ RECENTI ===
              _buildSezioneHeader(context, AppLocalizations.of(context)!.communityLatest, colorScheme,
                  icona: Icons.schedule),
              const SizedBox(height: 12),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: community.piuRecenti.length,
                itemBuilder: (context, index) {
                  return _buildPromptCard(
                    context,
                    community.piuRecenti[index],
                    colorScheme,
                    isDark,
                  );
                },
              ),
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// Header di sezione (es. "Trending", "Più recenti")
  Widget _buildSezioneHeader(
    BuildContext context,
    String titolo,
    ColorScheme colorScheme, {
    IconData? icona,
    Color? coloreIcona,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (icona != null) ...[
            Icon(icona, size: 20, color: coloreIcona ?? colorScheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            titolo,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  /// Card trending — orizzontale, più grande, con posizione
  Widget _buildTrendingCard(
    BuildContext context,
    PromptPubblico prompt,
    ColorScheme colorScheme,
    bool isDark,
    int posizione,
  ) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 12),
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
            Navigator.of(context).pushNamed(
              AppRoutes.dettaglioPromptPubblico,
              arguments: prompt.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Posizione e categoria
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '#${posizione + 1}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        prompt.categoria,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Titolo
                Text(
                  prompt.titolo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Autore
                Row(
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundColor: Color(prompt.autoreColore),
                      child: Text(
                        prompt.autoreNome.replaceFirst('@', '')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      prompt.autoreNome,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),

                const Spacer(),

                // Stats
                Row(
                  children: [
                    Icon(Icons.favorite, size: 14, color: Colors.red[300]),
                    const SizedBox(width: 3),
                    Text('${prompt.numerLike}',
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 10),
                    Icon(Icons.fork_right,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${prompt.numeroFork}',
                        style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Icon(Icons.star, size: 14, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text(
                      prompt.punteggio.toStringAsFixed(1),
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500),
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

  /// Card prompt standard — lista verticale
  Widget _buildPromptCard(
    BuildContext context,
    PromptPubblico prompt,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).pushNamed(
              AppRoutes.dettaglioPromptPubblico,
              arguments: prompt.id,
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Autore e categoria
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(prompt.autoreColore),
                      child: Text(
                        prompt.autoreNome.replaceFirst('@', '')[0].toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        prompt.autoreNome,
                        style:
                            Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        prompt.categoria,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Titolo
                Text(
                  prompt.titolo,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),

                // Descrizione
                Text(
                  prompt.descrizione,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),

                // Stats
                Row(
                  children: [
                    Icon(Icons.favorite, size: 14, color: Colors.red[300]),
                    const SizedBox(width: 3),
                    Text('${prompt.numerLike}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.fork_right,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${prompt.numeroFork}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 12),
                    Icon(Icons.comment_outlined,
                        size: 14, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 3),
                    Text('${prompt.commenti.length}',
                        style: Theme.of(context).textTheme.bodySmall),
                    const Spacer(),
                    Icon(Icons.star, size: 14, color: Colors.amber[600]),
                    const SizedBox(width: 2),
                    Text(
                      prompt.punteggio.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w500,
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

  /// Stato vuoto per ricerca senza risultati
  Widget _buildEmptyState(BuildContext context, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.communityNoResults,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
