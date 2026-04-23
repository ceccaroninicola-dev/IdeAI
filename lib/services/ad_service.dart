import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show debugPrint;

/// Servizio centralizzato per la gestione della pubblicità AdMob.
/// TEMPORANEAMENTE DISABILITATO: google_mobile_ads rimosso per diagnostica iOS.
/// Tutte le chiamate sono no-op sicure.
class AdService {
  static final AdService _istanza = AdService._interno();
  factory AdService() => _istanza;
  AdService._interno();

  bool _inizializzato = false;
  bool consensoRichiesto = false;

  Future<void> inizializza() async {
    debugPrint('[AdService] AdMob DISABILITATO (diagnostica iOS)');
    _inizializzato = true;
  }

  Future<void> richiestaConsensoGDPR() async {
    consensoRichiesto = true;
  }

  /// Restituisce sempre null — AdMob rimosso
  Object? creaBanner({VoidCallback? onCaricato, VoidCallback? onErrore}) =>
      null;

  void precaricaInterstitial() {}

  Future<bool> mostraInterstitial() async => false;

  bool get rewardedDisponibile => false;

  void precaricaRewarded() {}

  Future<bool> mostraRewarded() async => false;

  void dispose() {}
}
