import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/storage/hive_boxes.dart';
import 'core/storage/app_data_controller.dart';
import 'core/services/file_storage_service.dart';
import 'core/services/pdf_tools_service.dart';
import 'core/services/ads_service.dart';
import 'core/theme/app_theme.dart';
import 'app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  unawaited(
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]),
  );

  // Start Flutter immediately. Startup services are initialized
  // after the first Flutter frame so the native Android splash
  // is released as soon as possible.
  runApp(const PdfMasterApp());
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
      home: const StartupGate(),
    );
  }
}

class StartupGate extends StatefulWidget {
  const StartupGate({super.key});

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<_StartupData> _startup;

  @override
  void initState() {
    super.initState();
    _startup = _initialize();
  }

  Future<_StartupData> _initialize() async {
    await HiveBoxes.init();

    final storage = FileStorageService();
    final dataController = AppDataController(storage);
    final adsService = AdsService();

    // Ads must never block startup.
    unawaited(adsService.init());

    return _StartupData(
      storage: storage,
      dataController: dataController,
      pdfToolsService: PdfToolsService(storage),
      adsService: adsService,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartupData>(
      future: _startup,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _StartupLoadingScreen();
        }

        if (snapshot.hasError) {
          return _StartupErrorScreen(
            error: snapshot.error.toString(),
            onRetry: () {
              setState(() {
                _startup = _initialize();
              });
            },
          );
        }

        final data = snapshot.data!;

        return MultiProvider(
          providers: [
            Provider<FileStorageService>.value(
              value: data.storage,
            ),
            Provider<PdfToolsService>.value(
              value: data.pdfToolsService,
            ),
            Provider<AdsService>.value(
              value: data.adsService,
            ),
            ChangeNotifierProvider<AppDataController>.value(
              value: data.dataController,
            ),
          ],
          child: const AppShell(),
        );
      },
    );
  }
}

class _StartupData {
  final FileStorageService storage;
  final AppDataController dataController;
  final PdfToolsService pdfToolsService;
  final AdsService adsService;

  const _StartupData({
    required this.storage,
    required this.dataController,
    required this.pdfToolsService,
    required this.adsService,
  });
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 64,
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('PDF Master Tools'),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorScreen extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _StartupErrorScreen({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Startup failed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
