
import 'package:flutter/material.dart';
import '../services/ads_service.dart';

class AdsBannerWidget extends StatefulWidget {
  const AdsBannerWidget({super.key});

  @override
  State<AdsBannerWidget> createState() => _AdsBannerWidgetState();
}

class _AdsBannerWidgetState extends State<AdsBannerWidget> {
  String? bannerUrl;

  @override
  void initState() {
    super.initState();
    _loadBanner();
  }

  Future<void> _loadBanner() async {
    final url = await AdsService().getActiveBannerUrl();
    setState(() {
      bannerUrl = url;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (bannerUrl == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Image.network(
        bannerUrl!,
        fit: BoxFit.cover,
        height: 80,
      ),
    );
  }
}
