import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Every ad unit id the app uses, in one place.
///
/// [kUseTestAds] is the single switch between Google's official test ids
/// (always served, never at risk of policy violations or invalid-traffic
/// account flags during development) and your real production ids.
///
/// TO GO LIVE:
/// 1. Create Banner / Interstitial / Rewarded / Native ad units for this
///    app at https://apps.admob.com (App inventory -> your app -> Ad units).
/// 2. Paste the real ids into the `_prod*` constants below.
/// 3. Replace the AdMob APPLICATION_ID in
///    android/app/src/main/AndroidManifest.xml (currently Google's shared
///    test app id) with your real AdMob App ID.
/// 4. Flip [kUseTestAds] to false.
/// Steps 3-4 must both happen together -- shipping a real app id with
/// test ad unit ids (or vice versa) causes AdMob to reject fill.
class AdsService {
  AdsService._();

  /// Flip to `false` for the Play Store production build.
  static const bool kUseTestAds = true;

  // ---- Google's official test ad unit ids (safe to ship as-is in debug)
  static const _testBannerAndroid = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitialAndroid = 'ca-app-pub-3940256099942544/1033173712';
  static const _testRewardedAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const _testNativeAndroid = 'ca-app-pub-3940256099942544/2247696110';

  static const _testBannerIOS = 'ca-app-pub-3940256099942544/2934735716';
  static const _testInterstitialIOS = 'ca-app-pub-3940256099942544/4411468910';
  static const _testRewardedIOS = 'ca-app-pub-3940256099942544/1712485313';
  static const _testNativeIOS = 'ca-app-pub-3940256099942544/3986624511';

  // ---- Production ad unit ids -- REPLACE THESE before release ----------
  static const _prodBannerAndroid = 'ca-app-pub-REPLACE_ME/BANNER_ANDROID';
  static const _prodInterstitialAndroid = 'ca-app-pub-REPLACE_ME/INTERSTITIAL_ANDROID';
  static const _prodRewardedAndroid = 'ca-app-pub-REPLACE_ME/REWARDED_ANDROID';
  static const _prodNativeAndroid = 'ca-app-pub-REPLACE_ME/NATIVE_ANDROID';

  static const _prodBannerIOS = 'ca-app-pub-REPLACE_ME/BANNER_IOS';
  static const _prodInterstitialIOS = 'ca-app-pub-REPLACE_ME/INTERSTITIAL_IOS';
  static const _prodRewardedIOS = 'ca-app-pub-REPLACE_ME/REWARDED_IOS';
  static const _prodNativeIOS = 'ca-app-pub-REPLACE_ME/NATIVE_IOS';

  static String get bannerAdUnitId {
    if (kUseTestAds) return Platform.isIOS ? _testBannerIOS : _testBannerAndroid;
    return Platform.isIOS ? _prodBannerIOS : _prodBannerAndroid;
  }

  static String get interstitialAdUnitId {
    if (kUseTestAds) return Platform.isIOS ? _testInterstitialIOS : _testInterstitialAndroid;
    return Platform.isIOS ? _prodInterstitialIOS : _prodInterstitialAndroid;
  }

  static String get rewardedAdUnitId {
    if (kUseTestAds) return Platform.isIOS ? _testRewardedIOS : _testRewardedAndroid;
    return Platform.isIOS ? _prodRewardedIOS : _prodRewardedAndroid;
  }

  static String get nativeAdUnitId {
    if (kUseTestAds) return Platform.isIOS ? _testNativeIOS : _testNativeAndroid;
    return Platform.isIOS ? _prodNativeIOS : _prodNativeAndroid;
  }

  static bool _initialized = false;

  /// Call once at app startup (see main.dart). Safe to call more than
  /// once -- subsequent calls are no-ops.
  static Future<void> initialize() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();

    // Test-device registration: on a physical device, run the app once
    // and check `adb logcat | grep "Use RequestConfiguration"` (Android)
    // or the Xcode console (iOS) for your device's hashed test id, then
    // add it below so YOUR OWN taps never count as invalid traffic
    // against the real account once kUseTestAds is false.
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: kUseTestAds ? null : const [],
        tagForChildDirectedTreatment: TagForChildDirectedTreatment.unspecified,
        tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.unspecified,
      ),
    );
    _initialized = true;
  }

  // ---------------------------------------------------------------------
  // Interstitial: preload-then-show pattern with a frequency cap so a
  // user is never interrupted by two interstitials back to back --
  // "safe placement" means only between natural breakpoints (e.g. after
  // a completed PDF export), never mid-task or on app launch/exit.
  // ---------------------------------------------------------------------

  static InterstitialAd? _interstitial;
  static DateTime? _lastInterstitialShown;
  static const _minGapBetweenInterstitials = Duration(minutes: 3);

  static void preloadInterstitial() {
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('Interstitial failed to load: $error');
          _interstitial = null;
        },
      ),
    );
  }

  /// Shows a preloaded interstitial if one is ready AND the frequency cap
  /// has elapsed AND [canInterrupt] (caller-supplied: e.g. false while a
  /// file operation is still running) is true. Always safe to call --
  /// it's a no-op otherwise. Automatically preloads the next one after
  /// this one is dismissed.
  static Future<void> maybeShowInterstitial({bool canInterrupt = true}) async {
    final ad = _interstitial;
    if (ad == null || !canInterrupt) return;
    final last = _lastInterstitialShown;
    if (last != null && DateTime.now().difference(last) < _minGapBetweenInterstitials) return;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _interstitial = null;
        preloadInterstitial();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _interstitial = null;
        preloadInterstitial();
      },
    );
    _lastInterstitialShown = DateTime.now();
    _interstitial = null;
    await ad.show();
  }

  // ---------------------------------------------------------------------
  // Rewarded: same preload pattern, used for opt-in perks (e.g. unlocking
  // an extra export or removing a watermark for one action) -- never
  // required to use a core tool, per AdMob policy on rewarded placement.
  // ---------------------------------------------------------------------

  static RewardedAd? _rewarded;

  static void preloadRewarded() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewarded = ad,
        onAdFailedToLoad: (error) {
          if (kDebugMode) debugPrint('Rewarded ad failed to load: $error');
          _rewarded = null;
        },
      ),
    );
  }

  static bool get isRewardedReady => _rewarded != null;

  /// Returns true if the reward was actually granted (user watched to
  /// completion). Always check this before unlocking the perk.
  static Future<bool> showRewarded() async {
    final ad = _rewarded;
    if (ad == null) return false;
    _rewarded = null;

    final completer = Completer<bool>();
    var rewardGranted = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(rewardGranted);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        preloadRewarded();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await ad.show(
      onUserEarnedReward: (ad, reward) {
        rewardGranted = true;
      },
    );
    return completer.future;
  }

  static void dispose() {
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
  }
}
