// lib/widgets/google_ad_banner_widget.dart
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class GoogleAdBannerWidget extends StatefulWidget {
  const GoogleAdBannerWidget({super.key});

  @override
  State<GoogleAdBannerWidget> createState() => _GoogleAdBannerWidgetState();
}

class _GoogleAdBannerWidgetState extends State<GoogleAdBannerWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  // Для тестирования можно использовать 'ca-app-pub-3940256099942544/6300978111'
  // Для iOS: 'ca-app-pub-7353499788951001~2425547810'
  // Для Windows/Linux/macOS - AdMob баннеры пока не поддерживаются.
  final String adUnitId = 'ca-app-pub-7353499788951001~2425547810';
  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isAdLoaded = true;
          });
          debugPrint('Ad loaded: ${ad.adUnitId}');
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Ad failed to load: ${error.message}');
          ad.dispose();
        },
        onAdOpened: (ad) => debugPrint('Ad opened.'),
        onAdClosed: (ad) => debugPrint('Ad closed.'),
        onAdImpression: (ad) => debugPrint('Ad impression.'),
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_bannerAd != null && _isAdLoaded) {
      return SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      return const SizedBox
          .shrink(); // Ничего не показываем, если реклама не загружена
    }
  }
}
