import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../core/permissions/permission_service.dart';
import '../core/storage/local_store.dart';
import '../models/history_entry.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/history_section.dart';

/// Dedicated QR Scanner. Contains only camera scanning, flash, and its
/// own Scan History — no QR generation UI, controls, or history live
/// here; that all belongs to [QrGeneratorScreen] instead.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  MobileScannerController? _controller;
  PermissionOutcome? _permissionOutcome;
  bool _handledThisScan = false;
  bool _torchOn = false;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _history = _readHistory();
    _requestPermission();
  }

  List<HistoryEntry> _readHistory() =>
      LocalStore.instance.readBucket(StoreKeys.qrScanHistory).map(HistoryEntry.fromJson).toList();

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

  Future<void> _toggleTorch() async {
    await _controller?.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _saveToHistory(String value) async {
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: value,
      subtitle: 'Scanned',
      payload: value,
      createdAt: DateTime.now(),
    );
    await LocalStore.instance.pushToBucket(StoreKeys.qrScanHistory, entry.toJson(), maxItems: 100);
    if (!mounted) return;
    setState(() => _history = _readHistory());
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handledThisScan) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _handledThisScan = true;
    await _controller?.stop();

    await _saveToHistory(value);

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR code detected'),
        content: SelectableText(value),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
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

  Future<void> _clearHistory() async {
    await LocalStore.instance.clearBucket(StoreKeys.qrScanHistory);
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('QR Scanner', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
          if (_permissionOutcome == PermissionOutcome.granted)
            IconButton(
              tooltip: _torchOn ? 'Turn off flash' : 'Turn on flash',
              icon: Icon(_torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              onPressed: _toggleTorch,
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            _buildScannerArea(theme),
            const SizedBox(height: 28),
            HistorySection(
              title: 'Scan History',
              icon: Icons.qr_code_scanner_rounded,
              color: AppColors.qrPrimary,
              entries: _history,
              emptyMessage: 'Codes you scan will show up here.',
              onClear: _clearHistory,
              onTapEntry: (h) => showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Scanned QR code'),
                  content: SelectableText(h.payload),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        FileService.shareText(h.payload);
                      },
                      child: const Text('Share'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerArea(ThemeData theme) {
    if (_permissionOutcome == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_permissionOutcome != PermissionOutcome.granted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 340,
        child: Stack(
          alignment: Alignment.center,
          children: [
            MobileScanner(controller: _controller, onDetect: _onDetect),
            IgnorePointer(
              child: FractionallySizedBox(
                widthFactor: 0.6,
                heightFactor: 0.55,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.qrPrimary, width: 3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            const Positioned(
              bottom: 16,
              child: Text('Point camera at a QR code', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
