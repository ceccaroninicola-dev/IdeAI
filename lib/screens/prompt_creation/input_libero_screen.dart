import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/l10n/app_localizations.dart';
import 'package:ideai/providers/sessione_provider.dart';

/// Schermata di input libero — prima fase del flusso di creazione prompt.
/// Design minimal stile Apple: superfici pulite, teal come accento, ombre sottili.
class InputLiberoScreen extends StatefulWidget {
  const InputLiberoScreen({super.key});

  @override
  State<InputLiberoScreen> createState() => _InputLiberoScreenState();
}

class _InputLiberoScreenState extends State<InputLiberoScreen> {
  // Controller per il campo di testo
  final _testoController = TextEditingController();

  // Nodo di focus per gestire la tastiera
  final _focusNode = FocusNode();

  // Controller dello scroll per portare il campo in vista all'apertura tastiera
  final _scrollController = ScrollController();

  // Chiave del campo di testo per Scrollable.ensureVisible
  final _textFieldKey = GlobalKey();

  // Indica se il bottone di invio deve essere attivo
  bool _testoValido = false;

  @override
  void initState() {
    super.initState();
    // Ascolta i cambiamenti del testo per abilitare/disabilitare il bottone
    _testoController.addListener(() {
      setState(() {
        _testoValido = _testoController.text.trim().length >= 5;
      });
    });
    // Quando il campo riceve il focus, scorre automaticamente
    // per renderlo visibile sopra la tastiera
    _focusNode.addListener(_gestisciFocus);
  }

  /// Porta il campo di testo in vista quando riceve il focus
  void _gestisciFocus() {
    if (_focusNode.hasFocus) {
      // Ritardo per attendere l'apertura della tastiera
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        final ctx = _textFieldKey.currentContext;
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
    _focusNode.removeListener(_gestisciFocus);
    _testoController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Invia la frase e avvia l'analisi
  Future<void> _inviaFrase() async {
    if (!_testoValido) return;

    final provider = context.read<SessioneProvider>();
    final navigator = Navigator.of(context);

    // Avvia la sessione con la frase dell'utente
    await provider.avviaSessione(_testoController.text.trim());

    // Mostra eventuale errore API (il flusso continua con dati fallback)
    if (mounted && provider.errore != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(AppLocalizations.of(context)!.inputLiberoOfflineMode(provider.errore!))),
            ],
          ),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange[700],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      provider.cancellaErrore();
    }

    // Naviga alla schermata di conferma categoria
    if (mounted) {
      navigator.pushNamed(AppRoutes.confermaCategoria);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final staAnalizzando = context.watch<SessioneProvider>().staAnalizzando;

    return Scaffold(
      // Il body si ridimensiona quando appare la tastiera,
      // permettendo al campo di testo di rimanere visibile
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.inputLiberoTitle),
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
        child: SingleChildScrollView(
          controller: _scrollController,
          // Chiude la tastiera quando si trascina la vista
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titolo
              Text(
                AppLocalizations.of(context)!.inputLiberoHeading,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              // Istruzioni
              Text(
                AppLocalizations.of(context)!.inputLiberoDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 24),

              // Campo di testo principale — altezza fissa che si adatta
              // al contenuto, senza Expanded così resta in un ScrollView
              TextField(
                key: _textFieldKey,
                controller: _testoController,
                focusNode: _focusNode,
                maxLines: 10,
                minLines: 6,
                textAlignVertical: TextAlignVertical.top,
                enabled: !staAnalizzando,
                decoration: InputDecoration(
                  hintText: AppLocalizations.of(context)!.inputLiberoHint,
                  hintMaxLines: 3,
                  hintStyle: TextStyle(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                    fontSize: 15,
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.all(20),
                ),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),

              // Suggerimenti rapidi
              if (!staAnalizzando) ...[
                Text(
                  AppLocalizations.of(context)!.inputLiberoQuickExamples,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chipEsempio(
                      AppLocalizations.of(context)!.inputLiberoExampleEmail,
                      Icons.email_outlined,
                    ),
                    _chipEsempio(
                      AppLocalizations.of(context)!.inputLiberoExampleCode,
                      Icons.code,
                    ),
                    _chipEsempio(
                      AppLocalizations.of(context)!.inputLiberoExampleImage,
                      Icons.image_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              // Bottone di invio / indicatore di caricamento
              SizedBox(
                width: double.infinity,
                height: 56,
                child: staAnalizzando
                    ? _buildIndicatoreCaricamento(colorScheme)
                    : ElevatedButton.icon(
                        onPressed: _testoValido ? _inviaFrase : null,
                        icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                        label: Text(AppLocalizations.of(context)!.inputLiberoAnalyzeButton),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Chip cliccabile con esempio rapido — stile minimal teal
  Widget _chipEsempio(String testo, IconData icona) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      avatar: Icon(icona, size: 16, color: colorScheme.primary),
      label: Text(
        testo,
        style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
      ),
      backgroundColor: colorScheme.surfaceContainerLow,
      side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      onPressed: () {
        _testoController.text = testo;
        _testoController.selection = TextSelection.fromPosition(
          TextPosition(offset: testo.length),
        );
      },
    );
  }

  /// Indicatore di caricamento durante l'analisi AI
  Widget _buildIndicatoreCaricamento(ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            AppLocalizations.of(context)!.inputLiberoAnalyzing,
            style: TextStyle(
              color: colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
