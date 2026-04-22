import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show VoidCallback;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Servizio centralizzato per la gestione della pubblicità AdMob.
/// Gestisce banner, interstitial e rewarded video.
///
/// Su Flutter Web, la pubblicità NON viene mostrata (AdMob non supporta web).
/// Il servizio espone metodi sicuri che su web sono no-op.
class AdService {
  /// Singleton
  static final AdService _istanza = AdService._interno();
  factory AdService() => _istanza;
  AdService._interno();

  // === ID PUBBLICITARI ===
  // Android
  static const _androidBannerId = 'ca-app-pub-7715514651566286/8619753512';
  static const _androidInterstitialId = 'ca-app-pub-7715514651566286/9101167493';
  static const _androidRewardedId = 'ca-app-pub-7715514651566286/7788085822';

  // iOS
  static const _iosBannerId = 'ca-app-pub-7715514651566286/5949925391';
  static const _iosInterstitialId = 'ca-app-pub-7715514651566286/5993590170';
  static const _iosRewardedId = 'ca-app-pub-7715514651566286/3768949762';

  /// Seleziona l'ID corretto in base alla piattaforma (dart:io)
  static String get bannerId {
    if (kIsWeb) return '';
    return Platform.isIOS ? _iosBannerId : _androidBannerId;
  }
  static String get interstitialId {
    if (kIsWeb) return '';
    return Platform.isIOS ? _iosInterstitialId : _androidInterstitialId;
  }
  static String get rewardedId {
    if (kIsWeb) return '';
    return Platform.isIOS ? _iosRewardedId : _androidRewardedId;
  }

  // === STATO INTERNO ===
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  bool _inizializzato = false;

  /// Timestamp dell'ultimo interstitial mostrato (rate limiting: max 1 ogni 3 min)
  DateTime? _ultimoInterstitial;
  static const _intervalloMinimoInterstitial = Duration(minutes: 3);

  /// Flag: l'utente ha dato il consenso alla pubblicità personalizzata
  bool _consensoPersonalizzata = false;

  /// Flag: il consenso GDPR è stato richiesto
  bool consensoRichiesto = false;

  /// Inizializza il Mobile Ads SDK.
  /// Chiamare una sola volta all'avvio dell'app.
  /// Se l'inizializzazione fallisce (es. GADApplicationIdentifier errato su iOS),
  /// l'app continua senza pubblicità.
  Future<void> inizializza() async {
    // Su web non facciamo nulla — AdMob non supporta web
    if (kIsWeb) {
      debugPrint('[AdService] Web rilevato — pubblicità disabilitata');
      return;
    }

    if (_inizializzato) return;

    try {
      await MobileAds.instance.initialize();
      _inizializzato = true;
      debugPrint('[AdService] SDK AdMob inizializzato');
    } on PlatformException catch (e) {
      debugPrint('[AdService] Errore piattaforma AdMob (ads disabilitate): $e');
    } catch (e) {
      debugPrint('[AdService] Errore inizializzazione AdMob (ads disabilitate): $e');
    }
  }

  /// Richiede il consenso GDPR tramite il Google UMP SDK.
  /// Mostra il form di consenso se necessario (utenti EU).
  /// Se AdMob non è inizializzato, salta la richiesta.
  Future<void> richiestaConsensoGDPR() async {
    if (kIsWeb || !_inizializzato) {
      consensoRichiesto = true;
      return;
    }

    try {
      final params = ConsentRequestParameters();

      ConsentInformation.instance.requestConsentInfoUpdate(
        params,
        () async {
          try {
            if (await ConsentInformation.instance.isConsentFormAvailable()) {
              _mostraFormConsenso();
            } else {
              consensoRichiesto = true;
              _consensoPersonalizzata = true;
              debugPrint('[AdService] Consenso non necessario per questa regione');
            }
          } catch (e) {
            debugPrint('[AdService] Errore verifica form consenso: $e');
            consensoRichiesto = true;
          }
        },
        (error) {
          debugPrint('[AdService] Errore richiesta consenso: ${error.message}');
          consensoRichiesto = true;
          _consensoPersonalizzata = false;
        },
      );
    } catch (e) {
      debugPrint('[AdService] Eccezione consenso GDPR: $e');
      consensoRichiesto = true;
    }
  }

  /// Mostra il form di consenso GDPR
  void _mostraFormConsenso() {
    ConsentForm.loadConsentForm(
      (consentForm) {
        consentForm.show((formError) {
          if (formError != null) {
            debugPrint('[AdService] Errore form consenso: ${formError.message}');
          }
          // Dopo che l'utente ha risposto, verifica lo stato
          _verificaStatoConsenso();
        });
      },
      (formError) {
        debugPrint('[AdService] Errore caricamento form: ${formError.message}');
        consensoRichiesto = true;
      },
    );
  }

  /// Verifica lo stato del consenso dopo la risposta dell'utente
  Future<void> _verificaStatoConsenso() async {
    final stato = await ConsentInformation.instance.getConsentStatus();
    consensoRichiesto = true;

    // Se lo stato è OBTAINED o NOT_REQUIRED, l'utente ha accettato
    // o non è necessario il consenso
    _consensoPersonalizzata = (stato == ConsentStatus.obtained ||
        stato == ConsentStatus.notRequired);

    debugPrint('[AdService] Stato consenso: $stato '
        '(personalizzata: $_consensoPersonalizzata)');
  }

  // === BANNER ===

  /// Crea un BannerAd pronto per essere inserito in un widget.
  /// Restituisce null su web.
  BannerAd? creaBanner({VoidCallback? onCaricato, VoidCallback? onErrore}) {
    if (kIsWeb || !_inizializzato) return null;

    return BannerAd(
      adUnitId: bannerId,
      size: AdSize.banner, // 320x50 standard
      request: _creaRichiesta(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          debugPrint('[AdService] Banner caricato');
          onCaricato?.call();
        },
        onAdFailedToLoad: (ad, errore) {
          debugPrint('[AdService] Banner fallito: ${errore.message}');
          ad.dispose();
          onErrore?.call();
        },
      ),
    );
  }

  // === INTERSTITIAL ===

  /// Pre-carica un interstitial. Chiamare all'inizio della sessione domande.
  void precaricaInterstitial() {
    if (kIsWeb || !_inizializzato) return;

    InterstitialAd.load(
      adUnitId: interstitialId,
      request: _creaRichiesta(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          debugPrint('[AdService] Interstitial pre-caricato');
        },
        onAdFailedToLoad: (errore) {
          debugPrint('[AdService] Interstitial fallito: ${errore.message}');
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Mostra l'interstitial se disponibile e se sono passati almeno 3 minuti
  /// dall'ultimo. Restituisce `true` se l'ad è stato mostrato.
  Future<bool> mostraInterstitial() async {
    if (kIsWeb || !_inizializzato) return false;

    // Rate limiting: massimo 1 ogni 3 minuti
    if (_ultimoInterstitial != null) {
      final trascorso = DateTime.now().difference(_ultimoInterstitial!);
      if (trascorso < _intervalloMinimoInterstitial) {
        debugPrint('[AdService] Interstitial bloccato: '
            'ultimo ${trascorso.inSeconds}s fa (min: 180s)');
        return false;
      }
    }

    if (_interstitialAd == null) {
      debugPrint('[AdService] Nessun interstitial disponibile');
      return false;
    }

    final completer = Completer<bool>();

    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Interstitial chiuso');
        ad.dispose();
        _interstitialAd = null;
        _ultimoInterstitial = DateTime.now();
        // Pre-carica il prossimo
        precaricaInterstitial();
        completer.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, errore) {
        debugPrint('[AdService] Interstitial errore show: ${errore.message}');
        ad.dispose();
        _interstitialAd = null;
        precaricaInterstitial();
        completer.complete(false);
      },
    );

    _interstitialAd!.show();
    return completer.future;
  }

  // === REWARDED VIDEO ===

  /// Pre-carica un rewarded video.
  void precaricaRewarded() {
    if (kIsWeb || !_inizializzato) return;

    RewardedAd.load(
      adUnitId: rewardedId,
      request: _creaRichiesta(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('[AdService] Rewarded video pre-caricato');
        },
        onAdFailedToLoad: (errore) {
          debugPrint('[AdService] Rewarded video fallito: ${errore.message}');
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Verifica se un rewarded video è disponibile
  bool get rewardedDisponibile => _rewardedAd != null && !kIsWeb;

  /// Mostra il rewarded video. Restituisce true se l'utente ha completato
  /// la visione e ha ottenuto la ricompensa (sblocco suggerimenti).
  Future<bool> mostraRewarded() async {
    if (kIsWeb || !_inizializzato || _rewardedAd == null) return false;

    final completer = Completer<bool>();
    bool ricompensaOttenuta = false;

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('[AdService] Rewarded chiuso (ricompensa: $ricompensaOttenuta)');
        ad.dispose();
        _rewardedAd = null;
        // Pre-carica il prossimo
        precaricaRewarded();
        completer.complete(ricompensaOttenuta);
      },
      onAdFailedToShowFullScreenContent: (ad, errore) {
        debugPrint('[AdService] Rewarded errore show: ${errore.message}');
        ad.dispose();
        _rewardedAd = null;
        precaricaRewarded();
        completer.complete(false);
      },
    );

    _rewardedAd!.show(
      onUserEarnedReward: (ad, ricompensa) {
        debugPrint('[AdService] Ricompensa ottenuta: '
            '${ricompensa.amount} ${ricompensa.type}');
        ricompensaOttenuta = true;
      },
    );

    return completer.future;
  }

  // === UTILITÀ ===

  /// Crea la richiesta pubblicitaria con le impostazioni di consenso.
  /// Se l'utente non ha dato il consenso, richiede annunci non personalizzati.
  AdRequest _creaRichiesta() {
    if (_consensoPersonalizzata) {
      return const AdRequest();
    }
    // Annunci non personalizzati (GDPR-safe)
    return const AdRequest(
      extras: {'npa': '1'}, // Non-Personalized Ads
    );
  }

  /// Libera tutte le risorse
  void dispose() {
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _interstitialAd = null;
    _rewardedAd = null;
  }
}
