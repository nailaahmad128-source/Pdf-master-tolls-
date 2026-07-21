import 'dart:io';
import 'dart:ui' show PointMode;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../core/permissions/permission_service.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../services/pdf_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/dialogs_and_sheets.dart';

/// Document scanner. The animated edge-detection viewfinder below is this
/// screen's "ready to capture" chrome; the actual capture + edge
/// detection + perspective correction is performed by the platform's
/// native document scanner (ML Kit Document Scanner on Android,
/// VisionKit on iOS) via `flutter_doc_scanner` -- that native flow owns
/// the camera UI for the few seconds of an actual scan, then hands
/// control back here with the cropped page image(s).
class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  bool _flashOn = false;
  int _filterIndex = 0;
  final _filters = const ['Auto', 'B&W', 'Grayscale', 'Original', 'HD'];
  final List<String> _pages = [];
  bool _scanning = false;

  late final AnimationController _scanController =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  /// Applies the selected filter chip to a freshly captured page and
  /// writes the result into the app's working directory so every page
  /// this screen manages lives in one predictable place.
  Future<String> _applyFilterAndStore(String sourcePath) async {
    final bytes = await File(sourcePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return sourcePath;

    img.Image processed = decoded;
    switch (_filters[_filterIndex]) {
      case 'B&W':
        processed = img.grayscale(decoded);
        processed = img.contrast(processed, contrast: 160);
        break;
      case 'Grayscale':
        processed = img.grayscale(decoded);
        break;
      case 'HD':
        // Upscale-safe: only sharpen, never enlarge beyond source
        // resolution (that would fabricate detail, not add real quality).
        processed = img.convolution(decoded, filter: [0, -1, 0, -1, 5, -1, 0, -1, 0], div: 1);
        break;
      case 'Original':
      case 'Auto':
      default:
        processed = decoded;
    }

    final dir = await FileService.workingDirectory();
    final outPath = p.join(dir.path, 'scan_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await File(outPath).writeAsBytes(img.encodeJpg(processed, quality: 92));
    return outPath;
  }

  /// Best-effort extraction of image file paths from the scanner
  /// plugin's result. `flutter_doc_scanner` types this as `dynamic`
  /// because Android/iOS return slightly different shapes; this handles
  /// the documented shapes (a List of paths, or a Map carrying an
  /// 'images'/'Uri' entry) and otherwise treats the value as a single
  /// path so a real device response that differs from what's described
  /// in the plugin's docs still has a reasonable fallback rather than
  /// silently discarding the scan.
  List<String> _extractPaths(dynamic result) {
    if (result == null) return [];
    if (result is List) {
      return result.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (result is Map) {
      final candidate = result['images'] ?? result['Uri'] ?? result['uri'] ?? result['pdfUri'];
      if (candidate is List) return candidate.map((e) => e.toString()).toList();
      if (candidate is String) return [candidate];
    }
    if (result is String && result.isNotEmpty) return [result];
    return [];
  }

  Future<void> _scan() async {
    final outcome = await PermissionService.camera();
    if (outcome != PermissionOutcome.granted) {
      if (!mounted) return;
      await PermissionService.handleDenied(context, outcome, featureName: 'Document scanning');
      return;
    }

    setState(() => _scanning = true);
    try {
      final dynamic result = await FlutterDocScanner().getScannedDocumentAsImages(page: 20);
      final rawPaths = _extractPaths(result);
      if (rawPaths.isEmpty) {
        if (!mounted) return;
        setState(() => _scanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No pages were scanned.')),
        );
        return;
      }
      final processed = <String>[];
      for (final raw in rawPaths) {
        final cleanPath = raw.startsWith('file://') ? raw.substring(7) : raw;
        if (!await File(cleanPath).exists()) continue;
        processed.add(await _applyFilterAndStore(cleanPath));
      }
      if (!mounted) return;
      setState(() {
        _pages.addAll(processed);
        _scanning = false;
      });
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Scan failed: ${e.message ?? 'unknown error'}')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Something went wrong while scanning.')),
      );
    }
  }

  Future<void> _saveAsPdf() async {
    if (_pages.isEmpty) return;
    try {
      final outputPath = await PdfService.imagesToPdf(_pages, outputName: 'Scan');
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      if (!mounted) return;
      setState(() => _pages.clear());
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.scanPrimary,
          title: 'Scan saved as PDF',
          message: 'Your scanned document is ready to share or save.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
    } on PdfOperationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _saveAsImages() async {
    if (_pages.isEmpty) return;
    final library = context.read<LibraryProvider>();
    for (final path in _pages) {
      await library.registerFile(path);
    }
    if (!mounted) return;
    setState(() => _pages.clear());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pages saved to Recent Files.')),
    );
  }

  void _openReviewSheet() {
    AppBottomSheet.show(
      context,
      title: '${_pages.length} page${_pages.length == 1 ? '' : 's'} scanned',
      children: [
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _pages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_pages[i]), width: 80, height: 110, fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: InkWell(
                    onTap: () {
                      setState(() => _pages.removeAt(i));
                      Navigator.pop(context);
                      if (_pages.isNotEmpty) _openReviewSheet();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 12, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SecondaryButton(
                label: 'Save as Images',
                icon: Icons.image_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  _saveAsImages();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PrimaryButton(
                label: 'Save as PDF',
                icon: Icons.picture_as_pdf_rounded,
                onPressed: () {
                  Navigator.pop(context);
                  _saveAsPdf();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final scanQuality = context.watch<SettingsProvider>().defaultScanQuality;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient viewfinder chrome (native scanner owns the real camera feed)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A22), Color(0xFF101014)],
                  ),
                ),
                child: Center(
                  child: Icon(Icons.image_outlined, size: 64, color: Colors.white.withOpacity(0.15)),
                ),
              ),
            ),
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.82,
                heightFactor: 0.62,
                child: Stack(
                  children: [
                    Positioned.fill(child: CustomPaint(painter: _EdgeFramePainter())),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedBuilder(
                        animation: _scanController,
                        builder: (context, child) {
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              final top = constraints.maxHeight * _scanController.value;
                              return Stack(
                                children: [
                                  Positioned(
                                    top: top,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 3,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            AppColors.accentCoral.withOpacity(0),
                                            AppColors.accentCoral,
                                            AppColors.accentCoral.withOpacity(0),
                                          ],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.accentCoral.withOpacity(0.7),
                                            blurRadius: 8,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleIconButton(
                    icon: Icons.close_rounded,
                    background: Colors.white.withOpacity(0.12),
                    iconColor: Colors.white,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.success.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('Tap the shutter to scan · $scanQuality', style: AppTextStyles.caption(Colors.white)),
                  ),
                  CircleIconButton(
                    icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                    background: Colors.white.withOpacity(0.12),
                    iconColor: Colors.white,
                    onPressed: () => setState(() => _flashOn = !_flashOn),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final selected = i == _filterIndex;
                          return GestureDetector(
                            onTap: () => setState(() => _filterIndex = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _filters[i],
                                style: AppTextStyles.label(selected ? Colors.black : Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _thumbStack(),
                        GestureDetector(
                          onTap: _scanning ? null : _scan,
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: _scanning
                                ? const Padding(
                                    padding: EdgeInsets.all(18),
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                                  )
                                : Container(
                                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                                  ),
                          ),
                        ),
                        CircleIconButton(
                          icon: Icons.cameraswitch_rounded,
                          background: Colors.white.withOpacity(0.12),
                          iconColor: Colors.white,
                          onPressed: null, // camera facing is controlled by the native scanner UI
                        ),
                      ],
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

  Widget _thumbStack() {
    return GestureDetector(
      onTap: _pages.isEmpty ? null : _openReviewSheet,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withOpacity(0.12),
              border: Border.all(color: Colors.white.withOpacity(0.4)),
            ),
            child: _pages.isEmpty
                ? const Icon(Icons.photo_library_rounded, color: Colors.white, size: 20)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(File(_pages.last), fit: BoxFit.cover),
                  ),
          ),
          if (_pages.isNotEmpty)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: const BoxDecoration(color: AppColors.accentCoral, shape: BoxShape.circle),
                child: Center(
                  child: Text('${_pages.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EdgeFramePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accentCoral
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    canvas.drawRRect(rrect, paint);

    final cornerPaint = Paint()
      ..color = AppColors.accentCoral
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const double len = 22;
    final corners = [
      [Offset(0, len), Offset.zero, Offset(len, 0)],
      [Offset(size.width - len, 0), Offset(size.width, 0), Offset(size.width, len)],
      [Offset(0, size.height - len), Offset(0, size.height), Offset(len, size.height)],
      [
        Offset(size.width - len, size.height),
        Offset(size.width, size.height),
        Offset(size.width, size.height - len),
      ],
    ];
    for (final c in corners) {
      canvas.drawPoints(PointMode.polygon, c, cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
