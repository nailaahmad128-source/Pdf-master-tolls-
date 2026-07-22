import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;

import '../core/permissions/permission_service.dart';
import '../core/storage/local_store.dart';
import '../models/history_entry.dart';
import '../services/file_service.dart';
import '../services/ocr_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  OcrLanguage _language = OcrLanguage.english;
  final List<String> _pageImagePaths = [];
  List<OcrPageResult> _pageResults = [];
  String get _combinedText => OcrService.combineText(_pageResults);

  bool _processing = false;
  String _statusLabel = '';
  double? _downloadProgress; // non-null while a language pack downloads
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _history = _readHistory();
  }

  List<HistoryEntry> _readHistory() =>
      LocalStore.instance.readBucket(StoreKeys.ocrHistory).map(HistoryEntry.fromJson).toList();

  // -------------------------------------------------------------------
  // Capture
  // -------------------------------------------------------------------

  Future<void> _pickImages(ImageSource source, {bool multiPage = false}) async {
    final outcome = source == ImageSource.camera ? await PermissionService.camera() : await PermissionService.photosOrStorage();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'OCR image access');
      return;
    }
    final picker = ImagePicker();
    if (multiPage && source == ImageSource.gallery) {
      final picked = await picker.pickMultiImage(imageQuality: 95);
      if (picked.isEmpty) return;
      setState(() {
        _pageImagePaths.addAll(picked.map((x) => x.path));
        _pageResults = [];
      });
    } else {
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;
      setState(() {
        _pageImagePaths.add(picked.path);
        _pageResults = [];
      });
    }
    await _runOcr();
  }

  void _addAnotherPage() => _showSourceSheet(context, multiPage: true);

  void _removePage(int index) {
    setState(() {
      _pageImagePaths.removeAt(index);
      _pageResults = [];
    });
  }

  void _clearAll() {
    setState(() {
      _pageImagePaths.clear();
      _pageResults = [];
    });
  }

  // -------------------------------------------------------------------
  // OCR
  // -------------------------------------------------------------------

  Future<void> _runOcr() async {
    if (_pageImagePaths.isEmpty) return;

    // Arabic/Urdu use Tesseract, whose language pack is downloaded once
    // and cached offline afterward -- fetch it first if missing, with
    // a real progress bar instead of a generic spinner.
    if (!await OcrService.isLanguageReady(_language)) {
      setState(() {
        _downloadProgress = 0;
        _statusLabel = 'Downloading ${_language.label} OCR language pack…';
      });
      try {
        await OcrService.ensureLanguageReady(
          _language,
          onProgress: (v) => setState(() => _downloadProgress = v),
        );
      } catch (e) {
        setState(() => _downloadProgress = null);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
        return;
      }
      setState(() => _downloadProgress = null);
    }

    setState(() {
      _processing = true;
      _statusLabel = _pageImagePaths.length > 1 ? 'Reading page 1 of ${_pageImagePaths.length}…' : 'Reading text…';
    });
    try {
      final results = await OcrService.recognizeMultiPage(
        _pageImagePaths,
        _language,
        onPageDone: (done, total) {
          if (!mounted) return;
          setState(() => _statusLabel = total > 1 ? 'Reading page $done of $total…' : 'Reading text…');
        },
      );
      setState(() {
        _pageResults = results;
        _processing = false;
      });
      if (_combinedText.trim().isNotEmpty) {
        await _saveToHistory(_combinedText);
      }
    } catch (e) {
      setState(() => _processing = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _saveToHistory(String text) async {
    final name = _pageImagePaths.length > 1
        ? '${_pageImagePaths.length} pages'
        : p.basename(_pageImagePaths.first);
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: name,
      subtitle: text.length > 80 ? '${text.substring(0, 80)}…' : text,
      payload: text,
      createdAt: DateTime.now(),
    );
    await LocalStore.instance.pushToBucket(StoreKeys.ocrHistory, entry.toJson(), maxItems: 100);
    setState(() => _history = _readHistory());
  }

  // -------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------

  Future<void> _copyText() async {
    if (_combinedText.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _combinedText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
  }

  Future<void> _shareText() async {
    if (_combinedText.isEmpty) return;
    await FileService.shareText(_combinedText);
  }

  Future<void> _exportAsTxt() async {
    if (_combinedText.isEmpty) return;
    try {
      final path = await OcrService.exportToTxt(_combinedText, outputName: 'OCR_${DateTime.now().millisecondsSinceEpoch}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved ${p.basename(path)}'),
        action: SnackBarAction(label: 'Share', onPressed: () => FileService.shareFile(path)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _exportAsPdf() async {
    if (_pageResults.isEmpty) return;
    try {
      final path = await OcrService.exportToPdf(
        _pageResults,
        _language,
        outputName: 'OCR_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved ${p.basename(path)}'),
        action: SnackBarAction(label: 'Share', onPressed: () => FileService.shareFile(path)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  // -------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('OCR — Image to Text', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: PopupMenuButton<OcrLanguage>(
                initialValue: _language,
                onSelected: (v) {
                  setState(() => _language = v);
                  if (_pageImagePaths.isNotEmpty) _runOcr();
                },
                itemBuilder: (context) => OcrLanguage.values
                    .map((l) => PopupMenuItem(value: l, child: Text(l.label)))
                    .toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Wrap(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_language.label, style: AppTextStyles.label(theme.colorScheme.onSurface)),
                      const SizedBox(width: 4),
                      Icon(Icons.expand_more_rounded, size: 18, color: theme.colorScheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            if (_pageImagePaths.isEmpty)
              GestureDetector(
                onTap: () => _showSourceSheet(context),
                child: Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_rounded, size: 44, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(height: 8),
                        Text('Tap to choose an image', style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              )
            else
              _PageStrip(
                paths: _pageImagePaths,
                onAddPage: _addAnotherPage,
                onRemovePage: _removePage,
                onClearAll: _clearAll,
              ),
            if (_downloadProgress != null) ...[
              const SizedBox(height: 16),
              _LanguagePackBanner(language: _language, progress: _downloadProgress!),
            ],
            const SizedBox(height: 20),
            Wrap(
              children: [
                Icon(Icons.text_snippet_rounded, size: 18, color: AppColors.scanPrimary),
                const SizedBox(width: 8),
                Text('Extracted Text', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                const Spacer(),
                if (_processing) ...[
                  Text(_statusLabel, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 8),
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                _combinedText.isEmpty ? 'Recognized text will appear here.' : _combinedText,
                textDirection: _language.isRightToLeft ? TextDirection.rtl : TextDirection.ltr,
                style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              children: [
                Expanded(
                  child: SecondaryButton(label: 'Copy', icon: Icons.copy_rounded, onPressed: _copyText),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryButton(label: 'Share', icon: Icons.ios_share_rounded, onPressed: _shareText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              children: [
                Expanded(
                  child: SecondaryButton(label: 'Save as TXT', icon: Icons.description_rounded, onPressed: _exportAsTxt),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(label: 'Save as PDF', icon: Icons.picture_as_pdf_rounded, onPressed: _exportAsPdf),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Wrap(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent OCR', style: AppTextStyles.title(theme.colorScheme.onSurface)),
                if (_history.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      await LocalStore.instance.clearBucket(StoreKeys.ocrHistory);
                      setState(() => _history = []);
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_history.isEmpty)
              Text('No OCR activity yet.', style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant))
            else
              ..._history.map((h) => _RecentOcrTile(
                    fileName: h.title,
                    preview: h.subtitle,
                    meta: _relativeDate(h.createdAt),
                    onTap: () => setState(() {
                      _pageResults = [OcrPageResult(imagePath: '', text: h.payload, pageNumber: 1)];
                      _pageImagePaths.clear();
                    }),
                  )),
          ],
        ),
      ),
    );
  }

  String _relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${diff.inDays} days ago';
  }

  void _showSourceSheet(BuildContext context, {bool multiPage = false}) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.camera, multiPage: multiPage);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: Text(multiPage ? 'Choose from gallery' : 'Choose from gallery (multi-select for multi-page)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImages(ImageSource.gallery, multiPage: true);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguagePackBanner extends StatelessWidget {
  final OcrLanguage language;
  final double progress;
  const _LanguagePackBanner({required this.language, required this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.scanSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            children: [
              const Icon(Icons.download_rounded, size: 18, color: AppColors.scanPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Downloading ${language.label} OCR pack (one-time, then works offline)',
                  style: AppTextStyles.bodySmall(theme.colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surface,
              color: AppColors.scanPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageStrip extends StatelessWidget {
  final List<String> paths;
  final VoidCallback onAddPage;
  final void Function(int index) onRemovePage;
  final VoidCallback onClearAll;
  const _PageStrip({
    required this.paths,
    required this.onAddPage,
    required this.onRemovePage,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${paths.length} page${paths.length == 1 ? '' : 's'}', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
            TextButton(onPressed: onClearAll, child: const Text('Clear all')),
          ],
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: paths.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              if (index == paths.length) {
                return GestureDetector(
                  onTap: onAddPage,
                  child: Container(
                    width: 90,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Icon(Icons.add_rounded, color: theme.colorScheme.onSurfaceVariant),
                  ),
                );
              }
              final path = paths[index];
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(path), width: 90, height: 110, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemovePage(index),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentOcrTile extends StatelessWidget {
  final String fileName;
  final String preview;
  final String meta;
  final VoidCallback? onTap;
  const _RecentOcrTile({required this.fileName, required this.preview, required this.meta, this.onTap});

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
            child: Wrap(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.scanSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.text_snippet_rounded, color: AppColors.scanPrimary, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(fileName, style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                      const SizedBox(height: 2),
                      Text(preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(meta, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
