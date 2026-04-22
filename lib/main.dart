import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ideai/config/app_theme.dart';
import 'package:ideai/config/app_routes.dart';
import 'package:ideai/providers/theme_provider.dart';
import 'package:ideai/providers/sessione_provider.dart';
import 'package:ideai/providers/prompt_generato_provider.dart';
import 'package:ideai/providers/cronologia_provider.dart';
import 'package:ideai/providers/libreria_provider.dart';
import 'package:ideai/providers/confronto_ai_provider.dart';
import 'package:ideai/providers/community_provider.dart';
import 'package:ideai/services/api_service.dart';
import 'package:ideai/services/ad_service.dart';

/// Entry point dell'applicazione IdeAI.
///
/// TEST NUCLEARE iOS: su iOS avvia SOLO un MaterialApp minimale
/// senza nessun plugin, provider o widget custom.
/// Se funziona → il crash è nei nostri plugin/provider.
/// Se crasha → il problema è nella configurazione nativa iOS.
void main() {
  // ── TEST NUCLEARE iOS ──
  // Avvia un'app minimale senza NESSUN plugin per isolare il crash nativo.
  // Quando il test è superato, rimuovere questo blocco e ripristinare il flusso normale.
  if (!kIsWeb && Platform.isIOS) {
    runApp(
      MaterialApp(
        title: 'IdeAI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF6C63FF),
          brightness: Brightness.light,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF6C63FF),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const _TestNucleareiOS(),
      ),
    );
    return;
  }

  // ── FLUSSO NORMALE (Android / Web) ──
  runZonedGuarded(
    () async {
      debugPrint('[IdeAI] APP STARTING...');
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        debugPrint('[IdeAI] FlutterError: ${details.exception}');
        debugPrint('[IdeAI] Stack: ${details.stack}');
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('[IdeAI] PlatformError: $error');
        debugPrint('[IdeAI] Stack: $stack');
        return true;
      };

      const apiKey = String.fromEnvironment('OPENAI_API_KEY');
      if (apiKey.isNotEmpty) {
        ApiService().impostaApiKey(apiKey);
      }

      if (!kIsWeb && Platform.isAndroid) {
        _inizializzaAdMobSafe();
      }

      runApp(const PromptMasterApp());
    },
    (error, stack) {
      debugPrint('[IdeAI] Errore non gestito nella zona: $error');
      debugPrint('[IdeAI] Stack: $stack');
    },
  );
}

/// Inizializza AdMob in modo sicuro. Chiamata SOLO su Android.
Future<void> _inizializzaAdMobSafe() async {
  try {
    await AdService().inizializza();
    AdService().richiestaConsensoGDPR();
  } catch (e, stack) {
    debugPrint('[IdeAI] AdMob init fallita (app continua senza ads): $e');
    debugPrint('[IdeAI] Stack: $stack');
  }
}

/// Schermata di test nucleare iOS — nessun plugin, nessun provider, nessun widget custom.
class _TestNucleareiOS extends StatelessWidget {
  const _TestNucleareiOS();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFF6C63FF), size: 80),
              const SizedBox(height: 24),
              const Text(
                'IdeAI funziona su iOS!',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Test nucleare superato.\n'
                'Nessun plugin inizializzato.\n'
                'Versione: 1.0.12+13',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget radice dell'applicazione (Android / Web).
class PromptMasterApp extends StatelessWidget {
  const PromptMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SessioneProvider()),
        ChangeNotifierProvider(create: (_) => PromptGeneratoProvider()),
        ChangeNotifierProvider(create: (_) => CronologiaProvider()),
        ChangeNotifierProvider(create: (_) => LibreriaProvider()),
        ChangeNotifierProvider(create: (_) => ConfrontoAIProvider()),
        ChangeNotifierProvider(create: (_) => CommunityProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'IdeAI',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.temaChiaro,
            darkTheme: AppTheme.temaScuro,
            themeMode: themeProvider.modalitaTema,
            initialRoute: AppRoutes.home,
            routes: AppRoutes.rotte,
          );
        },
      ),
    );
  }
}
