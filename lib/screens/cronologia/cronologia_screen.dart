import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/providers/cronologia_provider.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/services/export_service.dart';
import 'package:ideai/widgets/barra_navigazione.dart';

/// Schermata Cronologia — mostra tutti i prompt salvati dall'utente.
/// Include ricerca, filtri per categoria, swipe per eliminare e menu azioni.
class CronologiaScreen extends StatefulWidget {
  const CronologiaScreen({super.key});

  @override
  State<CronologiaScreen> createState() => _CronologiaScreenState();
}

class _CronologiaScreenState extends State<CronologiaScreen> {
  /// Controller per la barra di ricerca
  final _cercaController = TextEditingController();

  /// Categoria filtro attiva ("Tutti" = nessun filtro)
  String _categoriaFiltro = 'Tutti';

  /// Categorie disponibili per i chip filtro
  static const _categorie = ['Tutti', 'Coding', 'Scrittura', 'Immagini'];

  @override
  void dispose() {
    _cercaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cronologia = context.watch<CronologiaProvider>();

    // Applica ricerca e filtro
    final risultati = cronologia.cercaEFiltra(
      _cercaController.text,
      _categoriaFiltro,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.historyAppBarTitle),
        automaticallyImplyLeading: false,
      ),
      // Barra di navigazione inferiore
      bottomNavigationBar: const BarraNavigazione(indiceCorrente: 2),
      body: SafeArea(
        child: Column(
          children: [
            // -- Barra di ricerca --
            _buildBarraRicerca(colorScheme, isDark),

            // -- Chip filtro per categoria --
            _buildChipFiltro(colorScheme),

            // -- Lista risultati o stato vuoto --
            Expanded(
              child: risultati.isEmpty
                  ? _buildStatoVuoto(colorScheme, cronologia)
                  : _buildLista(risultati, colorScheme, isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ========== BARRA DI RICERCA ==========

  Widget _buildBarraRicerca(ColorScheme colorScheme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: TextField(
        controller: _cercaController,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.historySearchHint,
          prefixIcon: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
          suffixIcon: _cercaController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear,
                    color: colorScheme.onSurfaceVariant,
                    size: 18,
                  ),
                  onPressed: () {
                    _cercaController.clear();
                    setState(() {});
                  },
                )
              : null,
          filled: true,
          fillColor: colorScheme.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ========== CHIP FILTRO CATEGORIA ==========

  Widget _buildChipFiltro(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categorie.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, indice) {
            final categoria = _categorie[indice];
            final selezionato = _categoriaFiltro == categoria;
            return FilterChip(
              label: Text(
                categoria,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight:
                      selezionato ? FontWeight.w600 : FontWeight.w400,
                  color: selezionato
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              selected: selezionato,
              onSelected: (_) => setState(() {
                _categoriaFiltro = categoria;
              }),
              selectedColor: colorScheme.primary,
              backgroundColor: colorScheme.surfaceContainerLow,
              checkmarkColor: colorScheme.onPrimary,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              showCheckmark: false,
            );
          },
        ),
      ),
    );
  }

  // ========== STATO VUOTO ==========

  Widget _buildStatoVuoto(
    ColorScheme colorScheme,
    CronologiaProvider cronologia,
  ) {
    // Se la cronologia è davvero vuota (nessun prompt salvato)
    final messaggioVuoto = cronologia.numeroPromptSalvati == 0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                messaggioVuoto
                    ? Icons.bookmark_outline_rounded
                    : Icons.search_off_rounded,
                size: 48,
                color: colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              messaggioVuoto
                  ? AppLocalizations.of(context)!.historyEmptyTitle
                  : AppLocalizations.of(context)!.historyNoResultsTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              messaggioVuoto
                  ? AppLocalizations.of(context)!.historyEmptyDescription
                  : AppLocalizations.of(context)!.historyNoResultsDescription,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ========== LISTA PROMPT ==========

  Widget _buildLista(
    List<ElementoCronologia> elementi,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      itemCount: elementi.length,
      itemBuilder: (context, indice) {
        final elemento = elementi[indice];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildCardPrompt(elemento, colorScheme, isDark),
        );
      },
    );
  }

  // ========== CARD SINGOLO PROMPT ==========

  Widget _buildCardPrompt(
    ElementoCronologia elemento,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    // Anteprima: prime 2 righe del testo completo
    final anteprima = _generaAnteprima(elemento.prompt.testoCompleto);

    return Dismissible(
      key: Key(elemento.id),
      direction: DismissDirection.endToStart,
      // Sfondo rosso con icona cestino
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 24),
      ),
      // Conferma eliminazione
      confirmDismiss: (_) => _confermaEliminazione(elemento, colorScheme),
      onDismissed: (_) {
        context.read<CronologiaProvider>().rimuoviPrompt(elemento.id);
        _mostraSnackbar(Icons.delete_outline, AppLocalizations.of(context)!.historyPromptDeleted);
      },
      child: Container(
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
            onTap: () => _apriPrompt(elemento),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Riga superiore: categoria + data + menu
                  Row(
                    children: [
                      // Icona e nome categoria
                      _buildBadgeCategoria(elemento.categoria, colorScheme),
                      const Spacer(),
                      // Data e ora
                      Text(
                        _formattaData(elemento.dataSalvataggio),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Menu tre puntini
                      _buildMenuAzioni(elemento, colorScheme),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Anteprima del prompt (prime 2 righe)
                  Text(
                    anteprima,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Riga inferiore: stelle + AI destinazione
                  Row(
                    children: [
                      // Punteggio a stelle
                      _buildStelline(
                        elemento.prompt.punteggioGlobale,
                        colorScheme,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${elemento.prompt.punteggioGlobale}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      // Badge AI destinazione
                      if (elemento.aiDestinazione != null &&
                          elemento.aiDestinazione != 'Generico')
                        _buildBadgeAi(elemento.aiDestinazione!, colorScheme),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ========== WIDGET HELPER ==========

  /// Badge con icona e nome della categoria
  Widget _buildBadgeCategoria(String categoria, ColorScheme colorScheme) {
    final dati = _datiCategoria(categoria);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: dati.colore.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(dati.icona, size: 14, color: dati.colore),
          const SizedBox(width: 5),
          Text(
            categoria,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: dati.colore,
            ),
          ),
        ],
      ),
    );
  }

  /// Badge dell'AI di destinazione
  Widget _buildBadgeAi(String ai, ColorScheme colorScheme) {
    final colore = _coloreAi(ai);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        ai,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: colore,
        ),
      ),
    );
  }

  /// Stelline per il punteggio
  Widget _buildStelline(double punteggio, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final valore = punteggio - i;
        return Icon(
          valore >= 1
              ? Icons.star_rounded
              : valore >= 0.5
                  ? Icons.star_half_rounded
                  : Icons.star_outline_rounded,
          color: colorScheme.primary,
          size: 16,
        );
      }),
    );
  }

  /// Menu azioni (tre puntini) per ogni prompt
  Widget _buildMenuAzioni(
    ElementoCronologia elemento,
    ColorScheme colorScheme,
  ) {
    return SizedBox(
      width: 32,
      height: 32,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        onSelected: (azione) => _eseguiAzione(azione, elemento),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'duplica',
            child: Row(
              children: [
                const Icon(Icons.copy_rounded, size: 18),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.historyMenuDuplicate),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'esporta',
            child: Row(
              children: [
                const Icon(Icons.ios_share_rounded, size: 18),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.historyMenuExport),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'elimina',
            child: Row(
              children: [
                Icon(Icons.delete_outline, size: 18, color: Colors.red.shade400),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(context)!.historyMenuDelete, style: TextStyle(color: Colors.red.shade400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ========== AZIONI ==========

  /// Esegue l'azione selezionata dal menu
  void _eseguiAzione(String azione, ElementoCronologia elemento) {
    switch (azione) {
      case 'duplica':
        context.read<CronologiaProvider>().duplicaPrompt(elemento.id);
        _mostraSnackbar(Icons.copy_rounded, AppLocalizations.of(context)!.historyPromptDuplicated);
        break;
      case 'esporta':
        _esportaPrompt(elemento);
        break;
      case 'elimina':
        final colorSchemeCurrent = Theme.of(context).colorScheme;
        _confermaEliminazione(elemento, colorSchemeCurrent)
            .then((confermato) {
          if (confermato == true && mounted) {
            context.read<CronologiaProvider>().rimuoviPrompt(elemento.id);
            _mostraSnackbar(Icons.delete_outline, AppLocalizations.of(context)!.historyPromptDeleted);
          }
        });
        break;
    }
  }

  /// Apre il prompt nella schermata post-generazione
  void _apriPrompt(ElementoCronologia elemento) {
    // Carica il prompt nel provider e naviga
    context.read<PromptGeneratoProvider>().caricaPrompt(elemento.prompt);
    Navigator.of(context).pushNamed(AppRoutes.postGenerazione);
  }

  /// Esporta il prompt (copia negli appunti come azione rapida)
  Future<void> _esportaPrompt(ElementoCronologia elemento) async {
    try {
      await ExportService.copiaTestoNegliAppunti(elemento.prompt);
      if (mounted) {
        _mostraSnackbar(Icons.check_circle, AppLocalizations.of(context)!.historyCopiedToClipboard);
      }
    } catch (e) {
      if (mounted) {
        _mostraSnackbar(Icons.error_outline, AppLocalizations.of(context)!.historyExportError);
      }
    }
  }

  /// Mostra dialog di conferma eliminazione
  Future<bool?> _confermaEliminazione(
    ElementoCronologia elemento,
    ColorScheme colorScheme,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(AppLocalizations.of(context)!.historyDeleteDialogTitle),
        content: Text(
          AppLocalizations.of(context)!.historyDeleteDialogMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppLocalizations.of(context)!.historyDialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)!.historyDialogConfirmDelete),
          ),
        ],
      ),
    );
  }

  /// Mostra snackbar con icona e messaggio
  void _mostraSnackbar(IconData icona, String messaggio) {
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

  // ========== FORMATTAZIONE ==========

  /// Genera l'anteprima dalle prime 2 righe del prompt
  String _generaAnteprima(String testo) {
    if (testo.isEmpty) return AppLocalizations.of(context)!.historyEmptyPrompt;
    final righe = testo.split('\n').where((r) => r.trim().isNotEmpty).toList();
    if (righe.isEmpty) return AppLocalizations.of(context)!.historyEmptyPrompt;
    if (righe.length == 1) return righe[0];
    return '${righe[0]}\n${righe[1]}';
  }

  /// Formatta la data in formato leggibile
  String _formattaData(DateTime data) {
    final ora = data.hour.toString().padLeft(2, '0');
    final minuti = data.minute.toString().padLeft(2, '0');
    final oggi = DateTime.now();

    // Se è oggi, mostra solo l'ora
    if (data.year == oggi.year &&
        data.month == oggi.month &&
        data.day == oggi.day) {
      return '${AppLocalizations.of(context)!.historyDatePrefixToday} $ora:$minuti';
    }

    // Se è ieri
    final ieri = oggi.subtract(const Duration(days: 1));
    if (data.year == ieri.year &&
        data.month == ieri.month &&
        data.day == ieri.day) {
      return '${AppLocalizations.of(context)!.historyDatePrefixYesterday} $ora:$minuti';
    }

    // Altrimenti data completa
    final giorno = data.day.toString().padLeft(2, '0');
    final mese = data.month.toString().padLeft(2, '0');
    return '$giorno/$mese/${data.year} $ora:$minuti';
  }

  /// Restituisce icona e colore per una categoria
  _DatiCategoria _datiCategoria(String categoria) {
    switch (categoria) {
      case 'Coding':
        return _DatiCategoria(Icons.code_rounded, const Color(0xFF7C3AED));
      case 'Immagini':
        return _DatiCategoria(Icons.image_rounded, const Color(0xFFEA580C));
      case 'Scrittura':
        return _DatiCategoria(Icons.edit_note_rounded, const Color(0xFF0891B2));
      default:
        return _DatiCategoria(Icons.auto_awesome, const Color(0xFF0D9488));
    }
  }

  /// Restituisce il colore associato a un'AI
  Color _coloreAi(String ai) {
    switch (ai) {
      case 'ChatGPT':
        return const Color(0xFF10A37F);
      case 'Claude':
        return const Color(0xFFD97706);
      case 'Gemini':
        return const Color(0xFF4285F4);
      default:
        return const Color(0xFF6B7280);
    }
  }
}

/// Dati associati a una categoria (icona + colore)
class _DatiCategoria {
  final IconData icona;
  final Color colore;
  const _DatiCategoria(this.icona, this.colore);
}
