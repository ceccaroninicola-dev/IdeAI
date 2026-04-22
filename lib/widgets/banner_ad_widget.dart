import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:ideai/services/ad_service.dart';

/// Widget che mostra un banner pubblicitario AdMob.
/// Su Flutter Web e iOS, NON mostra nulla (AdMob disabilitato).
/// Altezza fissa 50px, larghezza piena su Android.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _caricato = false;

  /// true se la piattaforma non supporta gli annunci (iOS o web)
  bool get _disabilitato => kIsWeb || Platform.isIOS;

  @override
  void initState() {
    super.initState();
    _caricaBanner();
  }

  void _caricaBanner() {
    // Su iOS e web non caricare nulla
    if (_disabilitato) return;

    _bannerAd = AdService().creaBanner(
      onCaricato: () {
        if (mounted) {
          setState(() => _caricato = true);
        }
      },
      onErrore: () {
        if (mounted) {
          setState(() => _caricato = false);
        }
      },
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Su iOS, web o se il banner non è caricato, non mostrare nulla
    if (_disabilitato || !_caricato || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      height: 50,
      alignment: Alignment.center,
      child: AdWidget(ad: _bannerAd!),
    );
  }
}
