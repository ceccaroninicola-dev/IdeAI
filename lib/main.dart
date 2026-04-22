import 'dart:async';
import 'dart:ui';
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
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

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

      // Inizializza AdMob in modo NON bloccante.
      // Se il SDK crasha (es. GADApplicationIdentifier non valido),
      // l'app parte comunque senza pubblicità.
      _inizializzaAdMobSafe();

      runApp(const PromptMasterApp());
    },
    (error, stack) {
      debugPrint('[IdeAI] Errore non gestito nella zona: $error');
      debugPrint('[IdeAI] Stack: $stack');
    },
  );
}

/// Inizializza AdMob in modo completamente sicuro.
/// Non blocca l'avvio dell'app e cattura qualsiasi errore.
Future<void> _inizializzaAdMobSafe() async {
  try {
    await AdService().inizializza();
    // Richiesta consenso GDPR (solo se AdMob si è inizializzato)
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
