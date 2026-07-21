import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/dialogs_and_sheets.dart';
import '../../widgets/state_views.dart';

enum _OverlayKind { signature, text }

/// One item placed on the page preview, tracked in normalized (0..1)
/// coordinates so it maps straight onto the PDF's actual page size
/// regardless of the on-screen preview resolution.
class _Overlay {
  final _OverlayKind kind;
  double x;
  double y;
  double width; // signature only
  double height; // signature only
  Uint8List? pngBytes; // signature only
  String? text; // text only
  double fontSize;

  _Overlay.signature(this.pngBytes, {this.x = 0.3, this.y = 0.4, this.width = 0.35, this.height = 0.12})
      : kind = _OverlayKind.signature,
        fontSize = 14;

  _Overlay.text(this.text, {this.x = 0.1, this.y = 0.85, this.fontSize = 16})
      : kind = _OverlayKind.text,
        width = 0,
        height = 0;
}

/// Fill & Sign: pick a PDF page, draw a signature and/or add typed text
/// fields, drag them into place on a live preview of that page, then
/// bake them into the PDF at the correct page-relative position.
///
/// Scope for this pass: one page per save (whichever page is currently
/// previewed). Documents that need a signature on more than one page can
/// be run through again for each page -- full multi-page placement in a
/// single pass is a larger UI (thumbnail rail + per-page overlay state)
/// left for a future round.
class FillSignScreen extends StatefulWidget {
  const FillSignScreen({super.key});

  @override
  State<FillSignScreen> createState() => _FillSignScreenState();
}

class _FillSignScreenState extends State<FillSignScreen> {
  String? _path;
  int? _pageCount;
  int _pageIndex = 0;
  Uint8List? _pagePng;
  double _pageAspectRatio = 0.77; // sensible A4-ish default until the real page loads
  bool _loadingPage = false;
  bool _saving = false;
  final List<_Overlay> _overlays = [];

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    final count = await PdfService.pageCount(path);
    setState(() {
      _path = path;
      _pageCount = count;
      _pageIndex = 0;
      _overlays.clear();
    });
    await _loadPage();
  }

  Future<void> _loadPage() async {
    if (_path == null) return;
    setState(() => _loadingPage = true);
    try {
      final png = await PdfService.renderPagePng(_path!, _pageIndex);
      final decoded = img.decodePng(png);
      if (!mounted) return;
      setState(() {
        _pagePng = png;
        if (decoded != null && decoded.height > 0) {
          _pageAspectRatio = decoded.width / decoded.height;
        }
        _loadingPage = false;
      });
    } on PdfOperationException catch (e) {
      if (!mounted) return;
      setState(() => _loadingPage = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _changePage(int delta) async {
    if (_pageCount == null) return;
    final next = _pageIndex + delta;
    if (next < 0 || next >= _pageCount!) return;
    setState(() {
      _pageIndex = next;
      _overlays.clear();
    });
    await _loadPage();
  }

  Future<void> _openSignaturePad() async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Draw your signature', style: AppTextStyles.title(Theme.of(ctx).colorScheme.onSurface)),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 220,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                  ),
                  child: Signature(controller: controller, backgroundColor: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Clear',
                      icon: Icons.refresh_rounded,
                      onPressed: controller.clear,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Use signature',
                      icon: Icons.check_rounded,
                      onPressed: () async {
                        if (controller.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Draw a signature first.')),
                          );
                          return;
                        }
                        final png = await controller.toPngBytes();
                        if (ctx.mounted) Navigator.pop(ctx, png);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
    if (bytes == null) return;
    setState(() => _overlays.add(_Overlay.signature(bytes)));
  }

  Future<void> _addTextField() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add text'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'e.g. Date, full name, initials'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Add')),
        ],
      ),
    );
    if (text == null || text.isEmpty) return;
    setState(() => _overlays.add(_Overlay.text(text)));
  }

  Future<void> _save() async {
    if (_path == null || _overlays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a signature or text field first.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final signatures = _overlays
          .where((o) => o.kind == _OverlayKind.signature)
          .map((o) => SignaturePlacement(
                pngBytes: o.pngBytes!,
                xFraction: o.x,
                yFraction: o.y,
                widthFraction: o.width,
                heightFraction: o.height,
              ))
          .toList();
      final texts = _overlays
          .where((o) => o.kind == _OverlayKind.text)
          .map((o) => TextPlacement(text: o.text!, xFraction: o.x, yFraction: o.y, fontSize: o.fontSize))
          .toList();

      final outputPath = await PdfService.signPdf(
        _path!,
        pageIndex: _pageIndex,
        signatures: signatures,
        texts: texts,
        outputName: 'Signed_PDF',
      );
      if (!mounted) return;
      await context.read<LibraryProvider>().registerFile(outputPath);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _overlays.clear();
      });
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: 'PDF signed',
          message: 'Page ${_pageIndex + 1} now includes your signature and any text you added.',
          confirmLabel: 'Share',
          cancelLabel: 'Done',
          onConfirm: () => FileService.shareFile(outputPath),
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong saving this PDF.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Fill & Sign', style: AppTextStyles.headline(theme.colorScheme.onSurface)),
        actions: [
          if (_pageCount != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(child: Text('Page ${_pageIndex + 1} of $_pageCount')),
            ),
        ],
      ),
      body: SafeArea(
        child: _path == null
            ? EmptyStateView(
                icon: Icons.draw_rounded,
                title: 'No PDF selected',
                message: 'Choose a PDF to add a signature, initials, or typed fields.',
                actionLabel: 'Choose PDF',
                onAction: _pickPdf,
              )
            : Column(
                children: [
                  Expanded(
                    child: _loadingPage || _pagePng == null
                        ? const Center(child: CircularProgressIndicator())
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: _PagePreview(
                              pageBytes: _pagePng!,
                              aspectRatio: _pageAspectRatio,
                              overlays: _overlays,
                              onOverlayMoved: (i, dx, dy) => setState(() {
                                _overlays[i].x = (_overlays[i].x + dx).clamp(0.0, 1.0);
                                _overlays[i].y = (_overlays[i].y + dy).clamp(0.0, 1.0);
                              }),
                              onOverlayRemoved: (i) => setState(() => _overlays.removeAt(i)),
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: _pageIndex == 0 ? null : () => _changePage(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Add signature',
                            icon: Icons.draw_rounded,
                            onPressed: _openSignaturePad,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Add text',
                            icon: Icons.text_fields_rounded,
                            onPressed: _addTextField,
                          ),
                        ),
                        IconButton(
                          onPressed: (_pageCount ?? 0) - 1 <= _pageIndex ? null : () => _changePage(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: PrimaryButton(
                      label: _saving ? 'Saving…' : 'Save signed PDF',
                      icon: Icons.check_circle_rounded,
                      loading: _saving,
                      onPressed: _overlays.isEmpty ? null : _save,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Renders the page image with draggable overlay chips on top. Drag
/// deltas are converted from pixels to page-fraction units using the
/// rendered box size, so placement stays correct at any preview scale.
class _PagePreview extends StatelessWidget {
  final Uint8List pageBytes;
  final double aspectRatio;
  final List<_Overlay> overlays;
  final void Function(int index, double dx, double dy) onOverlayMoved;
  final void Function(int index) onOverlayRemoved;

  const _PagePreview({
    required this.pageBytes,
    required this.aspectRatio,
    required this.overlays,
    required this.onOverlayMoved,
    required this.onOverlayRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: AspectRatio(
        // Sizing the box to the page's own aspect ratio (rather than
        // filling the available area with BoxFit.contain) keeps the
        // rendered image edge-to-edge with this widget's bounds, so a
        // drag delta expressed as a fraction of this box's size maps
        // 1:1 onto the PDF page -- no letterboxing gap to account for.
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LayoutBuilder(
              builder: (context, box) {
                return Stack(
                  children: [
                    Positioned.fill(child: Image.memory(pageBytes, fit: BoxFit.fill)),
                    ...List.generate(overlays.length, (i) {
                      final o = overlays[i];
                      return Positioned(
                        left: o.x * box.maxWidth,
                        top: o.y * box.maxHeight,
                        child: GestureDetector(
                          onPanUpdate: (details) => onOverlayMoved(
                            i,
                            details.delta.dx / box.maxWidth,
                            details.delta.dy / box.maxHeight,
                          ),
                          onLongPress: () => onOverlayRemoved(i),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.pdfPrimary, width: 1.5),
                              color: Colors.white.withOpacity(0.6),
                            ),
                            child: o.kind == _OverlayKind.signature
                                ? SizedBox(
                                    width: o.width * box.maxWidth,
                                    height: o.height * box.maxHeight,
                                    child: Image.memory(o.pngBytes!, fit: BoxFit.contain),
                                  )
                                : Text(o.text!, style: TextStyle(fontSize: o.fontSize * 0.8)),
                          ),
                        ),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
