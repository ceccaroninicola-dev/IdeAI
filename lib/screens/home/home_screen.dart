import 'package:flutter/material.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/providers/theme_provider.dart';
import 'package:ideai/widgets/barra_navigazione.dart';
import 'package:provider/provider.dart';

/// Schermata principale (Home) dell'app IdeAI.
/// Design minimal ispirato ad Apple: superfici pulite, ombre sottili, teal come accento.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Impedisci il pop del browser sulla rotta Home (è la radice)
    return PopScope(
      canPop: false,
      child: Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        automaticallyImplyLeading: false,
        actions: [
          // Icona profilo utente
          IconButton(
            icon: Icon(
              Icons.person_outline,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: AppLocalizations.of(context)!.tooltipMyProfile,
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.profilo);
            },
          ),
          // Toggle tema chiaro/scuro
          IconButton(
            icon: Icon(
              themeProvider.modalitaTema == ThemeMode.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: AppLocalizations.of(context)!.tooltipChangeTheme,
            onPressed: () => themeProvider.cambiaTema(),
          ),
          // Impostazioni (API key)
          IconButton(
            icon: Icon(
              Icons.settings_outlined,
              color: colorScheme.onSurfaceVariant,
            ),
            tooltip: AppLocalizations.of(context)!.tooltipSettings,
            onPressed: () {
              Navigator.of(context).pushNamed(AppRoutes.impostazioni);
            },
          ),
        ],
      ),
      // Barra di navigazione inferiore
      bottomNavigationBar: const BarraNavigazione(indiceCorrente: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icona dell'app con sfondo teal morbido
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.auto_awesome,
                    size: 48,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Titolo principale
                Text(
                  'IdeAI',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 8),

                // Sottotitolo
                Text(
                  AppLocalizations.of(context)!.homeSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),

                // Card "Crea nuovo prompt"
                _buildCardAzione(
                  context: context,
                  icona: Icons.add_circle_outline,
                  etichetta: AppLocalizations.of(context)!.createNewPromptTitle,
                  descrizione: AppLocalizations.of(context)!.createNewPromptSubtitle,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.inputLibero);
                  },
                ),
                const SizedBox(height: 12),

                // Card "Libreria"
                _buildCardAzione(
                  context: context,
                  icona: Icons.library_books_outlined,
                  etichetta: AppLocalizations.of(context)!.libraryTitle,
                  descrizione: AppLocalizations.of(context)!.librarySubtitle,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.libreria);
                  },
                ),
                const SizedBox(height: 12),

                // Card "Community"
                _buildCardAzione(
                  context: context,
                  icona: Icons.people_outline,
                  etichetta: AppLocalizations.of(context)!.communityTitle,
                  descrizione: AppLocalizations.of(context)!.communitySubtitle,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.community);
                  },
                ),
                const SizedBox(height: 12),

                // Card "Cronologia"
                _buildCardAzione(
                  context: context,
                  icona: Icons.history,
                  etichetta: AppLocalizations.of(context)!.historyTitle,
                  descrizione: AppLocalizations.of(context)!.historySubtitle,
                  isDark: isDark,
                  colorScheme: colorScheme,
                  onPressed: () {
                    Navigator.of(context).pushNamed(AppRoutes.cronologia);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  /// Card azione stile Apple — ombra sottile, padding generoso, angoli morbidi
  Widget _buildCardAzione({
    required BuildContext context,
    required IconData icona,
    required String etichetta,
    required String descrizione,
    required bool isDark,
    required ColorScheme colorScheme,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
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
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icona con sfondo teal morbido
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icona, color: colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                // Testo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        etichetta,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        descrizione,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                // Freccia di navigazione
                Icon(
                  Icons.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
