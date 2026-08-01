import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/permissions/permission_service.dart';
import '../core/storage/local_store.dart';
import '../models/history_entry.dart';
import '../providers/library_provider.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/creation_flow.dart';
import '../widgets/history_section.dart';

/// Dedicated QR Generator. Contains only QR creation, save-to-gallery,
/// share, and its own Generated QR History — no camera or scanning
/// controls live here; that all belongs to [QrScannerScreen] instead.
class QrGeneratorScreen extends StatefulWidget {
  const QrGeneratorScreen({super.key});

  @override
  State<QrGeneratorScreen> createState() => _QrGeneratorScreenState();
}

class _QrGeneratorScreenState extends State<QrGeneratorScreen> {
  final GlobalKey _qrKey = GlobalKey();
  final TextEditingController _textController = TextEditingController();
  String _contentType = 'URL';
  String _generatedContent = '';
  bool _savingToGallery = false;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _history = _readHistory();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<HistoryEntry> _readHistory() =>
      LocalStore.instance.readBucket(StoreKeys.qrGeneratedHistory).map(HistoryEntry.fromJson).toList();

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
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: text.length > 60 ? '${text.substring(0, 60)}…' : text,
      subtitle: _contentType,
      payload: text,
      createdAt: DateTime.now(),
    );
    await LocalStore.instance.pushToBucket(StoreKeys.qrGeneratedHistory, entry.toJson(), maxItems: 100);
    if (!mounted) return;
    setState(() => _history = _readHistory());
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
    if (_savingToGallery) return; // Prevent double tapping / duplicate creation.
    final outcome = await PermissionService.photosOrStorage();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'Saving to gallery');
      return;
    }
    setState(() => _savingToGallery = true);
    try {
      await runCreationFlow<void>(
        context: context,
        loadingTitle: 'Saving QR code…',
        loadingSubtitle: 'Please wait, this will only take a moment.',
        successTitle: 'QR Code Saved Successfully',
        task: () async {
          final png = await _captureQrPng();
          if (png == null) throw StateError('Could not capture the QR code image.');
          final dir = await getApplicationDocumentsDirectory();
          final outDir = Directory(p.join(dir.path, 'PDFMasterTools'));
          if (!await outDir.exists()) await outDir.create(recursive: true);
          final path = p.join(outDir.path, 'QR_${DateTime.now().millisecondsSinceEpoch}.png');
          await File(path).writeAsBytes(png);
          await context.read<LibraryProvider>().registerFile(path);
        },
      );
      if (!mounted) return;
      setState(() => _savingToGallery = false);
    } catch (_) {
      setState(() => _savingToGallery = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong saving this QR code.')),
      );
    }
  }

  Future<void> _shareQr() async {
    if (_generatedContent.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generate a QR code first.')),
      );
      return;
    }
    final png = await _captureQrPng();
    if (png == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'qr_share_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(path).writeAsBytes(png);
    if (!mounted) return;
    await FileService.shareFile(path);
  }

  Future<void> _clearHistory() async {
    await LocalStore.instance.clearBucket(StoreKeys.qrGeneratedHistory);
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayContent = _generatedContent.isEmpty ? 'PDF Master Tools' : _generatedContent;
    return Scaffold(
      appBar: AppBar(title: Text('QR Generator', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
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
                  child: SecondaryButton(
                    label: 'Save to Gallery',
                    icon: Icons.download_rounded,
                    onPressed: _savingToGallery ? null : _saveToGallery,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(label: 'Share', icon: Icons.share_rounded, onPressed: _shareQr),
                ),
              ],
            ),
            const SizedBox(height: 32),
            HistorySection(
              title: 'Generated QR History',
              icon: Icons.qr_code_2_rounded,
              color: AppColors.qrPrimary,
              entries: _history,
              emptyMessage: 'QR codes you generate will show up here.',
              onClear: _clearHistory,
              onTapEntry: (h) => setState(() {
                _generatedContent = h.payload;
                _textController.text = h.payload;
              }),
            ),
          ],
        ),
      ),
    );
  }
}
