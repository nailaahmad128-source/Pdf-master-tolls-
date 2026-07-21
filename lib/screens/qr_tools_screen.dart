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
  const QrToolsScreen({super.key});

  @override
  State<QrToolsScreen> createState() => _QrToolsScreenState();
}

class _QrToolsScreenState extends State<QrToolsScreen> {
  int _tab = 1; // 0 = Scan, 1 = Generate

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

class _GeneratorForm extends StatefulWidget {
  const _GeneratorForm();

  @override
  State<_GeneratorForm> createState() => _GeneratorFormState();
}

class _GeneratorFormState extends State<_GeneratorForm> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  String _contentType = 'URL';
  String _generatedContent = '';
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _history = QrHistoryStore.readAll();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  String get _hint => switch (_contentType) {
        'URL' => 'https://example.com',
        'Wi-Fi' => 'Network name, then password on a new line',
        'Contact' => 'Name, phone, email',
        'Email' => 'name@example.com',
        _ => 'Enter text to encode',
      };

  Future<void> _generate() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter some content to generate a QR code.')),
      );
      return;
    }
    setState(() => _generatedContent = text);
    await QrHistoryStore.add(
      title: text.length > 60 ? '${text.substring(0, 60)}…' : text,
      subtitle: _contentType,
      payload: text,
    );
    setState(() => _history = QrHistoryStore.readAll());
  }

  Future<Uint8List?> _captureQrPng() async {
    final boundary = _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _saveToGallery() async {
    if (_generatedContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a QR code first.')),
      );
      return;
    }
    final outcome = await PermissionService.photosOrStorage();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'Saving to gallery');
      return;
    }
    final png = await _captureQrPng();
    if (png == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final outDir = Directory(p.join(dir.path, 'PDFMasterTools'));
    if (!await outDir.exists()) await outDir.create(recursive: true);
    final path = p.join(outDir.path, 'QR_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(path).writeAsBytes(png);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('QR code saved.')));
  }

  Future<void> _shareQr() async {
    final png = await _captureQrPng();
    if (png == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'qr_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(path).writeAsBytes(png);
    if (!mounted) return;
    await FileService.shareFile(path);
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayContent = _generatedContent.isEmpty ? 'PDF Master Tools' : _generatedContent;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Center(
          child: RepaintBoundary(
            key: _qrKey,
            child: Container(
              width: 220,
              height: 220,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
                boxShadow: AppColors.cardShadow(theme.brightness, tint: AppColors.qrPrimary),
              ),
              child: QrImageView(
                data: displayContent,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                dataModuleStyle:
                    const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text('Content type', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ['Text', 'URL', 'Wi-Fi', 'Contact', 'Email']
              .map((label) => ChoiceChip(
                    label: Text(label),
                    selected: _contentType == label,
                    onSelected: (_) => setState(() => _contentType = label),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _textController,
          maxLines: _contentType == 'Wi-Fi' || _contentType == 'Contact' ? 3 : 1,
          decoration: InputDecoration(
            hintText: _hint,
            prefixIcon: const Icon(Icons.link_rounded),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Generate QR Code', icon: Icons.auto_awesome_rounded, onPressed: _generate),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(label: 'Save to Gallery', icon: Icons.download_rounded, onPressed: _saveToGallery),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SecondaryButton(label: 'Share', icon: Icons.share_rounded, onPressed: _shareQr),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('History', style: AppTextStyles.title(theme.colorScheme.onSurface)),
            if (_history.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await QrHistoryStore.clear();
                  setState(() => _history = []);
                },
                child: const Text('Clear'),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (_history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('No QR activity yet.', style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
          )
        else
          ..._history.map(
            (h) => _QrHistoryTile(
              label: h.title,
              icon: h.subtitle == 'Scanned' ? Icons.qr_code_scanner_rounded : Icons.qr_code_2_rounded,
              meta: _relativeDate(h.createdAt),
              onTap: () {
                setState(() {
                  _generatedContent = h.payload;
                  _textController.text = h.payload;
                });
              },
            ),
          ),
      ],
    );
  }
}

class _QrHistoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final String meta;
  final VoidCallback? onTap;
  const _QrHistoryTile({required this.label, required this.icon, required this.meta, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.qrSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.qrPrimary, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                ),
                Text(meta, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
