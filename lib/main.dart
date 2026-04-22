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
/// Avvolge tutto in un error zone per catturare crash non gestiti.
void main() {
  // LOG PRIMISSIMO: se non vediamo questo, il crash è nel runtime nativo
  debugPrint('[IdeAI] APP STARTING...');

  runZonedGuarded(
    () async {
      debugPrint('[IdeAI] BEFORE WIDGETS INIT...');
      WidgetsFlutterBinding.ensureInitialized();
      debugPrint('[IdeAI] AFTER WIDGETS INIT...');

      // Cattura errori Flutter (widget, rendering)
      FlutterError.onError = (details) {
        debugPrint('[IdeAI] FlutterError: ${details.exception}');
        debugPrint('[IdeAI] Stack: ${details.stack}');
      };

      // Cattura errori della piattaforma (plugin nativi, platform channels)
      PlatformDispatcher.instance.onError = (error, stack) {
        debugPrint('[IdeAI] PlatformError: $error');
        debugPrint('[IdeAI] Stack: $stack');
        return true;
      };

      // Inizializza la API key da variabile d'ambiente (se disponibile)
      const apiKey = String.fromEnvironment('OPENAI_API_KEY');
      if (apiKey.isNotEmpty) {
        ApiService().impostaApiKey(apiKey);
      }
      debugPrint('[IdeAI] API KEY CONFIGURED (present: ${apiKey.isNotEmpty})');

      // AdMob: COMPLETAMENTE DISABILITATO su iOS (crash nativo all'avvio).
      // Inizializza solo su Android (e mai su web).
      if (!kIsWeb && Platform.isAndroid) {
        debugPrint('[IdeAI] BEFORE ADMOB INIT (Android)...');
        _inizializzaAdMobSafe();
        debugPrint('[IdeAI] AFTER ADMOB INIT (Android)...');
      } else {
        debugPrint('[IdeAI] AdMob SKIPPED (iOS/web) — pubblicità disabilitata');
      }

      debugPrint('[IdeAI] BEFORE runApp...');
      runApp(const PromptMasterApp());
      debugPrint('[IdeAI] AFTER runApp...');
    },
    (error, stack) {
      debugPrint('[IdeAI] Errore non gestito nella zona: $error');
      debugPrint('[IdeAI] Stack: $stack');
    },
  );
}

/// Inizializza AdMob in modo completamente sicuro.
/// Chiamata SOLO su Android. Non blocca l'avvio dell'app.
Future<void> _inizializzaAdMobSafe() async {
  try {
    await AdService().inizializza();
    AdService().richiestaConsensoGDPR();
  } catch (e, stack) {
    debugPrint('[IdeAI] AdMob init fallita (app continua senza ads): $e');
    debugPrint('[IdeAI] Stack: $stack');
  }
}

/// Widget radice dell'applicazione.
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
