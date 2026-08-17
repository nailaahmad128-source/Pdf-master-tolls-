import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'core/storage/hive_boxes.dart';
import 'core/storage/app_data_controller.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/ads_service.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  await HiveBoxes.init();

  final storage = FileStorageService();
  final adsService = AdsService();

  // Ads must never block app startup.
  adsService.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<FileStorageService>.value(value: storage),
        Provider<AdsService>.value(value: adsService),
        ChangeNotifierProvider(
          create: (_) => AppDataController(storage),
        ),
      ],
      child: const PdfMasterApp(),
    ),
  );
}

class PdfMasterApp extends StatelessWidget {
  const PdfMasterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Master Tools',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
