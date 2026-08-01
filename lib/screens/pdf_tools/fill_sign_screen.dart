import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';

import '../../core/storage/local_store.dart';
import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/creation_flow.dart';
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

  // Signatures the user chose to keep for reuse (see "Save signature"),
  // stored as base64 PNG bytes under StoreKeys.savedSignatures.
  List<Map<String, dynamic>> _savedSignatures = [];

  static const double _minSignatureFraction = 0.08;
  static const double _maxSignatureFraction = 0.9;
  static const double _minFontSize = 8;
  static const double _maxFontSize = 48;

  @override
  void initState() {
    super.initState();
    _loadSavedSignatures();
  }

  void _loadSavedSignatures() {
    setState(() {
      _savedSignatures = LocalStore.instance.readBucket(StoreKeys.savedSignatures);
    });
  }

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

  /// Opens the signature options sheet: draw a brand new signature, or
  /// reuse one that was previously saved.
  Future<void> _showSignatureOptions() async {
    await AppBottomSheet.show(
      context,
      title: 'Add signature',
      children: [
        SheetAction(
          icon: Icons.draw_rounded,
          label: 'Draw new signature',
          onTap: () {
            Navigator.pop(context);
            _openSignaturePad();
          },
        ),
        if (_savedSignatures.isNotEmpty) ...[
          const Divider(),
          Text('Saved signatures', style: AppTextStyles.subtitle(Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 8),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _savedSignatures.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final entry = _savedSignatures[i];
                final bytes = base64Decode(entry['pngBase64'] as String);
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _overlays.add(_Overlay.signature(bytes)));
                  },
                  onLongPress: () => _confirmDeleteSavedSignature(entry['id'] as String),
                  child: Container(
                    width: 96,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                    ),
                    child: Image.memory(bytes, fit: BoxFit.contain),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap to use, long-press to delete.',
            style: AppTextStyles.caption(Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }

  void _confirmDeleteSavedSignature(String id) {
    Navigator.pop(context);
    AppDialog.show(
      context,
      AppDialog(
        icon: Icons.delete_outline_rounded,
        iconColor: AppColors.error,
        title: 'Delete saved signature?',
        message: 'This only removes it from your saved signatures, not from any PDF you already exported.',
        confirmLabel: 'Delete',
        destructive: true,
        onConfirm: () async {
          await LocalStore.instance.removeFromBucket(StoreKeys.savedSignatures, id);
          _loadSavedSignatures();
        },
      ),
    );
  }

  Future<void> _openSignaturePad() async {
    final controller = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.transparent,
    );
    var saveForReuse = true;
    final bytes = await showModalBottomSheet<Uint8List>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
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
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: saveForReuse,
                  onChanged: (v) => setSheetState(() => saveForReuse = v ?? true),
                  title: const Text('Save this signature for reuse'),
                ),
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
      ),
    );
    controller.dispose();
    if (bytes == null) return;
    if (saveForReuse) await _persistSignature(bytes);
    setState(() => _overlays.add(_Overlay.signature(bytes)));
  }

  /// Persists a drawn signature so it can be reused on future documents
  /// without redrawing it each time.
  Future<void> _persistSignature(Uint8List bytes) async {
    final entry = {
      'id': 'sig_${DateTime.now().microsecondsSinceEpoch}',
      'pngBase64': base64Encode(bytes),
      'createdAt': DateTime.now().toIso8601String(),
    };
    await LocalStore.instance.pushToBucket(StoreKeys.savedSignatures, entry, maxItems: 20);
    _loadSavedSignatures();
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

  void _moveOverlay(int index, double dxFraction, double dyFraction) {
    setState(() {
      final o = _overlays[index];
      o.x = (o.x + dxFraction).clamp(0.0, 1.0);
      o.y = (o.y + dyFraction).clamp(0.0, 1.0);
    });
  }

  /// Resizes the overlay at [index] by a drag delta expressed as a
  /// fraction of the page preview's size: grows/shrinks a signature's
  /// box, or grows/shrinks a text field's font size.
  void _resizeOverlay(int index, double dxFraction, double dyFraction) {
    setState(() {
      final o = _overlays[index];
      if (o.kind == _OverlayKind.signature) {
        o.width = (o.width + dxFraction).clamp(_minSignatureFraction, _maxSignatureFraction);
        o.height = (o.height + dyFraction).clamp(_minSignatureFraction, _maxSignatureFraction);
      } else {
        final delta = (dxFraction + dyFraction) * 60;
        o.fontSize = (o.fontSize + delta).clamp(_minFontSize, _maxFontSize);
      }
    });
  }

  void _copyOverlay(int index) {
  setState(() {
    final o=_overlays[index];
    if(o.kind==_OverlayKind.signature){
      _overlays.add(
        _Overlay.signature(
          o.pngBytes,
          x:(o.x+0.03).clamp(0.0,0.95),
          y:(o.y+0.03).clamp(0.0,0.95),
          width:o.width,
          height:o.height,
        ),
      );
    }else{
      _overlays.add(
        _Overlay.text(
          o.text,
          x:(o.x+0.03).clamp(0.0,0.95),
          y:(o.y+0.03).clamp(0.0,0.95),
          fontSize:o.fontSize,
        ),
      );
    }
  });
}

void _removeOverlay(int index) {
    setState(() => _overlays.removeAt(index));
  }

  Future<void> _save() async {
    if (_path == null || _overlays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a signature or text field first.')),
      );
      return;
    }
    if (_saving) return; // Prevent double tapping / duplicate creation.
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

      final outputPath = await runCreationFlow<String>(
        context: context,
        loadingTitle: 'Signing PDF…',
        loadingSubtitle: 'Adding your signature and text to page ${_pageIndex + 1}.',
        successTitle: 'PDF Signed Successfully',
        task: () async {
          final path = await PdfService.signPdf(
            _path!,
            pageIndex: _pageIndex,
            signatures: signatures,
            texts: texts,
            outputName: 'Signed_PDF',
          );
          await context.read<LibraryProvider>().registerFile(path);
          return path;
        },
      );
      if (!mounted) return;
      setState(() {
        _saving = false;
        _overlays.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Signed PDF saved to My Work.'),
        action: SnackBarAction(label: 'Share', onPressed: () => FileService.shareFile(outputPath)),
      ));
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
          if (_path != null)
            TextButton(
              onPressed: _pickPdf,
              child: const Text('Change PDF'),
            ),
        ],
      ),
      body: SafeArea(
        child: _path == null
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: EmptyStateView(
                  icon: Icons.draw_rounded,
                  title: 'No PDF selected',
                  message: 'Choose a PDF to add text and your signature to it.',
                  actionLabel: 'Choose PDF',
                  onAction: _pickPdf,
                ),
              )
            : Column(
                children: [
                  if ((_pageCount ?? 1) > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded),
                            onPressed: _pageIndex > 0 ? () => _changePage(-1) : null,
                          ),
                          Text(
                            'Page ${_pageIndex + 1} of ${_pageCount ?? 1}',
                            style: AppTextStyles.bodyMedium(theme.colorScheme.onSurface),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded),
                            onPressed: (_pageCount != null && _pageIndex < _pageCount! - 1)
                                ? () => _changePage(1)
                                : null,
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: _loadingPage || _pagePng == null
                        ? const LoadingStateView()
                        : Padding(
                            padding: const EdgeInsets.all(16),
                            child: _PagePreview(
                              pageBytes: _pagePng!,
                              aspectRatio: _pageAspectRatio,
                              overlays: _overlays,
                              onOverlayMoved: _moveOverlay,
                              onOverlayResized: _resizeOverlay,
                              onOverlayRemoved: _removeOverlay,
                  onOverlayCopied: _copyOverlay,
                            ),
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Signature',
                            icon: Icons.draw_rounded,
                            onPressed: _showSignatureOptions,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SecondaryButton(
                            label: 'Add text',
                            icon: Icons.text_fields_rounded,
                            onPressed: _addTextField,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: PrimaryButton(
                      label: _saving ? 'Saving…' : 'Save & Export PDF',
                      icon: Icons.check_rounded,
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PagePreview extends StatelessWidget {
  final Uint8List pageBytes;
  final double aspectRatio;
  final List<_Overlay> overlays;
  final void Function(int index, double dx, double dy) onOverlayMoved;
  final void Function(int index, double dx, double dy) onOverlayResized;
  final void Function(int index) onOverlayRemoved;
  final void Function(int index) onOverlayCopied;

  const _PagePreview({
    required this.pageBytes,
    required this.aspectRatio,
    required this.overlays,
    required this.onOverlayMoved,
    required this.onOverlayResized,
    required this.onOverlayRemoved,
    required this.onOverlayCopied,
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
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(child: Image.memory(pageBytes, fit: BoxFit.fill)),
                    ...List.generate(overlays.length, (i) {
                      final o = overlays[i];
                      final boxWidth = o.kind == _OverlayKind.signature ? o.width * box.maxWidth : null;
                      final boxHeight = o.kind == _OverlayKind.signature ? o.height * box.maxHeight : null;
                      return Positioned(
                        left: o.x * box.maxWidth,
                        top: o.y * box.maxHeight,
                        child: GestureDetector(
                          onPanUpdate: (details) => onOverlayMoved(
                            i,
                            details.delta.dx / box.maxWidth,
                            details.delta.dy / box.maxHeight,
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.pdfPrimary.withOpacity(0.6), width: 0.8),
                              color: Colors.transparent,
                            ),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                o.kind == _OverlayKind.signature
                                    ? SizedBox(
                                        width: boxWidth,
                                        height: boxHeight,
                                        child: Image.memory(o.pngBytes!, fit: BoxFit.contain),
                                      )
                                    : Text(o.text!, style: TextStyle(fontSize: o.fontSize * 0.8)),
                                // Explicit delete affordance for this
                                // overlay (in addition to the signature
                                // pad's own controls).
                                Positioned(
                                  top: -12,
                                  left: -12,
                                  child: GestureDetector(
                                    onTap: () => onOverlayCopied(i),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: Colors.blue,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.copy_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -12,
                                  right: -12,
                                  child: GestureDetector(
                                    onTap: () => onOverlayRemoved(i),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                      child: const Icon(Icons.close_rounded, size: 8, color: Colors.white),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: -12,
                                  left: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) => onOverlayResized(
                                      i,
                                      -details.delta.dx / box.maxWidth,
                                      -details.delta.dy / box.maxHeight,
                                    ),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: AppColors.brandIndigo,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

Positioned(
                                  bottom: -12,
                                  left: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) => onOverlayResized(
                                      i,
                                      -details.delta.dx / box.maxWidth,
                                      details.delta.dy / box.maxHeight,
                                    ),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: AppColors.brandIndigo,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

                                // Drag handle to resize this overlay in
                                // place, separate from the move gesture
                                // on the body of the overlay above.
                                Positioned(
                                  top: -12,
                                  right: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) => onOverlayResized(
                                      i,
                                      details.delta.dx / box.maxWidth,
                                      -details.delta.dy / box.maxHeight,
                                    ),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: const BoxDecoration(
                                        color: AppColors.brandIndigo,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.open_in_full_rounded,
                                        size: 8,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),

Positioned(
                                  bottom: -12,
                                  right: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (details) => onOverlayResized(
                                      i,
                                      details.delta.dx / box.maxWidth,
                                      details.delta.dy / box.maxHeight,
                                    ),
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(color: AppColors.brandIndigo, shape: BoxShape.circle),
                                      child: const Icon(Icons.open_in_full_rounded, size: 8, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
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
