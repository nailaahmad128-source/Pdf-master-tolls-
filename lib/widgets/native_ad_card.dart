import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/ads_service.dart';

/// Native ad rendered as its own card. Google's policy requires clear ad
/// disclosure, so this always shows an "Ad" label -- the surrounding
/// shape/spacing matches ToolCard so it doesn't feel visually foreign,
/// but it is never disguised as app content.
///
/// Safe placement: use between natural content groups (e.g. every 6-8
/// items in a long list, or once between "Recent" and "All tools" on a
/// screen) -- never as the very first item in a list, and never styled
/// to look identical to a tappable tool card.
class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isLoaded = false;
  bool _requested = false;

  void _loadAd() {
    if (_requested) return;
    _requested = true;
    _nativeAd = NativeAd(
      adUnitId: AdsService.nativeAdUnitId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _isLoaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          if (mounted) setState(() => _isLoaded = false);
        },
      ),
      // Matches the app's card corner radius / brand indigo CTA so the
      // native ad feels like part of the design system while the "Ad"
      // badge (rendered by the platform template) keeps it truthfully
      // labeled.
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Theme.of(context).colorScheme.surface,
        cornerRadius: 20,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF4F46E5),
          style: NativeTemplateFontStyle.bold,
          size: 14,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: Theme.of(context).colorScheme.onSurface,
          style: NativeTemplateFontStyle.bold,
          size: 15,
        ),
      ),
    )..load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadAd();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLoaded || _nativeAd == null) return const SizedBox.shrink();
    return Container(
      height: 132,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AdWidget(ad: _nativeAd!),
      ),
    );
  }
}
