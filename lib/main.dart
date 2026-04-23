import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
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

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // ignore: avoid_print
      print('[IdeAI] Dart main() avviato — piattaforma: '
          '${kIsWeb ? "web" : Platform.operatingSystem}');

      FlutterError.onError = (details) {
        // ignore: avoid_print
        print('[IdeAI] FlutterError: ${details.exception}');
        debugPrint('[IdeAI] Stack: ${details.stack}');
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        // ignore: avoid_print
        print('[IdeAI] PlatformError: $error');
        return true;
      };

      const apiKey = String.fromEnvironment('OPENAI_API_KEY');
      if (apiKey.isNotEmpty) {
        ApiService().impostaApiKey(apiKey);
      }

      // AdMob solo su Android. Su iOS: GADApplicationIdentifier rimosso da
      // Info.plist, nessuna chiamata al SDK, nessun conflitto nativo.
      if (!kIsWeb && Platform.isAndroid) {
        await _inizializzaAdMobSafe();
      }

      // ignore: avoid_print
      print('[IdeAI] Avvio runApp...');

      try {
        runApp(const PromptMasterApp());
      } catch (e, stack) {
        // ignore: avoid_print
        print('[IdeAI] CRASH in runApp: $e');
        // Mostra errore visibile all'utente
        runApp(MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.red.shade900,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'IdeAI ERRORE AVVIO:\n\n$e\n\n$stack',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
        ));
      }
    },
    (error, stack) {
      // ignore: avoid_print
      print('[IdeAI] Errore non gestito: $error\n$stack');
    },
  );
}

Future<void> _inizializzaAdMobSafe() async {
  try {
    await AdService().inizializza();
    AdService().richiestaConsensoGDPR();
  } catch (e) {
    // ignore: avoid_print
    print('[IdeAI] AdMob init fallita (non bloccante): $e');
  }
}

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
