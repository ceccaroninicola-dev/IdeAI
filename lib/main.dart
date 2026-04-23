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
      print('[IdeAI] === DART MAIN AVVIATO ===');
      // ignore: avoid_print
      print('[IdeAI] Piattaforma: ${kIsWeb ? "web" : Platform.operatingSystem}');

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

      // ============================================================
      // TEST DIAGNOSTICO: widget minimale per verificare il rendering.
      // Se vedi schermo BLU con "FLUTTER FUNZIONA" → il motore va,
      // il problema è nel codice app (tema/provider/rotte).
      // Se vedi ancora bianco → il motore Flutter non renderizza su iOS.
      // ============================================================
      // ignore: avoid_print
      print('[IdeAI] Avvio widget TEST DIAGNOSTICO...');

      runApp(
        MaterialApp(
          home: Scaffold(
            backgroundColor: const Color(0xFF1565C0),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'FLUTTER FUNZIONA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Piattaforma: ${kIsWeb ? "web" : Platform.operatingSystem}',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Build: 1.0.40+41',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                      decoration: TextDecoration.none,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
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
