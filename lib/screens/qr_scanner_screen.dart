import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/permissions/permission_service.dart';
import '../core/storage/local_store.dart';
import '../models/history_entry.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/dialogs_and_sheets.dart';

class QrToolsScreen extends StatefulWidget {
  final int initialTab;
  const QrToolsScreen({super.key, this.initialTab = 1});

  @override
  State<QrToolsScreen> createState() => _QrToolsScreenState();
}

class _QrToolsScreenState extends State<QrToolsScreen> {
  int _tab = 1; // 0 = Scan, 1 = Generate

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('QR Tools', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    _segment(context, 'Scan', Icons.qr_code_scanner_rounded, 0),
                    _segment(context, 'Generate', Icons.qr_code_2_rounded, 1),
                  ],
                ),
              ),
            ),
            Expanded(child: _tab == 0 ? const _ScannerView() : const _GeneratorForm()),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, String label, IconData icon, int index) {
    final theme = Theme.of(context);
    final selected = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? AppColors.cardShadow(theme.brightness, tint: AppColors.qrPrimary) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? AppColors.qrPrimary : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.label(selected ? AppColors.qrPrimary : theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared helpers for reading/writing the QR history bucket, so both the
/// Scan and Generate tabs log to the same persisted list.
class QrHistoryStore {
  QrHistoryStore._();

  static Future<void> add({required String title, required String subtitle, required String payload}) async {
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      payload: payload,
      createdAt: DateTime.now(),
    );
    await LocalStore.instance.pushToBucket(StoreKeys.qrHistory, entry.toJson(), maxItems: 100);
  }

  static List<HistoryEntry> readAll() =>
      LocalStore.instance.readBucket(StoreKeys.qrHistory).map(HistoryEntry.fromJson).toList();

  static Future<void> clear() => LocalStore.instance.clearBucket(StoreKeys.qrHistory);
}

// ---------------------------------------------------------------------
// Scan tab
// ---------------------------------------------------------------------

class _ScannerView extends StatefulWidget {
  const _ScannerView();

  @override
  State<_ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<_ScannerView> {
  MobileScannerController? _controller;
  PermissionOutcome? _permissionOutcome;
  bool _handledThisScan = false;

  @override
  void initState() {
    super.initState();
    _requestPermission();
  }

  Future<void> _requestPermission() async {
    final outcome = await PermissionService.camera();
    if (!mounted) return;
    setState(() {
      _permissionOutcome = outcome;
      if (outcome == PermissionOutcome.granted) {
        _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
      }
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledThisScan) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handledThisScan = true;
    await _controller?.stop();

    await QrHistoryStore.add(title: value, subtitle: 'Scanned', payload: value);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR code detected'),
        content: SelectableText(value),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              FileService.shareText(value);
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
    _handledThisScan = false;
    await _controller?.start();
  }

  @override
  Widget build(BuildContext context) {
    if (_permissionOutcome == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_permissionOutcome != PermissionOutcome.granted) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_photography_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Camera access is needed to scan QR codes.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Grant camera access', expand: false, onPressed: _requestPermission),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            IgnorePointer(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                heightFactor: 0.32,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.qrPrimary, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 24,
              child: Text('Point camera at a QR code', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

// ---------------------------------------------------------------------
// Generate tab
// ---------------------------------------------------------------------

