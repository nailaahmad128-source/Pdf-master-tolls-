import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_core/core.dart';

import 'core/storage/hive_boxes.dart';
import 'core/storage/app_data_controller.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/pdf_tools_service.dart';
import 'core/services/ads_service.dart';
import 'core/constants/app_config.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Registers the Syncfusion license used by the PDF engine (merge/split/
  // rotate/security/fill) and the PDF reader viewer. Without a valid key
  // Syncfusion's widgets show a trial watermark — see AppConfig and the
  // README for how to supply a real key (Syncfusion offers a free
  // Community License for qualifying individuals/small businesses).
  if (AppConfig.syncfusionLicenseKey.isNotEmpty) {
  }

  await HiveBoxes.init();

  final storage = FileStorageService();
  final dataController = AppDataController(storage);
  await dataController.purgeExpiredTrash();

  final adsService = AdsService();
  // Fire-and-forget: ads must never block app startup. If the SDK fails to
  // initialize (no network, restricted build, etc.) the app runs ad-free
  // rather than crashing or hanging on a splash screen.
  unawaited(adsService.init());

  runApp(
    MultiProvider(
      providers: [
        Provider<FileStorageService>.value(value: storage),
        Provider<PdfToolsService>.value(value: PdfToolsService(storage)),
        Provider<AdsService>.value(value: adsService),
        ChangeNotifierProvider<AppDataController>.value(value: dataController),
      ],
      child: const PdfMasterApp(),
    ),
  );
}

class PdfMasterApp extends StatelessWidget {
  const PdfMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final themeMode = switch (data.themeModeIndex) {
      1 => ThemeMode.light,
      2 => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'PDF Master Tools',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
