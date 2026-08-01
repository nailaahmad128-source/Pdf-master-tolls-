import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/core.dart';

import 'core/storage/local_store.dart';
import 'providers/library_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/splash_screen.dart';
import 'services/ads_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Local persistence must be ready before the first frame reads
  // settings/recents/favorites synchronously during build.
  await LocalStore.instance.init();

  // Syncfusion Flutter PDF (used for Merge/Split/Lock/Unlock) requires a
  // registered license key at startup -- free under Syncfusion's Community
  // License for qualifying individuals/small businesses, or a commercial
  // key otherwise. Without a valid key, PDF operations still run but show
  // a trial watermark/banner. Replace the placeholder below with your own
  // key from https://www.syncfusion.com/account/manage-trials/downloads
  // (Community License is free to generate) before shipping to production.
  SyncfusionLicense.registerLicense('YOUR_SYNCFUSION_LICENSE_KEY');

  runApp(const PdfMasterToolsApp());

  // AdMob: initialized after the first frame is already up rather than
  // awaited before runApp, so the splash screen paints immediately
  // instead of waiting on a network-bound SDK init (perf: startup
  // responsiveness). preloadInterstitial/preloadRewarded still run early
  // enough that the first ad opportunity later in the session has a
  // cached ad ready, since real usage (scanning, PDF export) always takes
  // longer than this init.
  unawaited(() async {
    await AdsService.initialize();
    AdsService.preloadInterstitial();
    AdsService.preloadRewarded();
  }());
}

/// Root widget. Theme now follows the persisted [SettingsProvider] value
/// (Dark / Light / System) instead of a hardcoded `ThemeMode.system` --
/// this is the only behavioral change here; the theme data, colors, and
/// navigation shell below are untouched.
class PdfMasterToolsApp extends StatelessWidget {
  const PdfMasterToolsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => LibraryProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'PDF Master Tools',

            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,

            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
