import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/library_provider.dart';
import '../../services/file_service.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/dialogs_and_sheets.dart';
import '../../widgets/state_views.dart';

enum _SplitMode { everyPage, customRange }

class SplitPdfScreen extends StatefulWidget {
  const SplitPdfScreen({super.key});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  String? _path;
  int? _pageCount;
  _SplitMode _mode = _SplitMode.everyPage;
  final _rangeController = TextEditingController();
  bool _splitting = false;

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
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
    });
  }

  /// Parses comma-separated ranges like "1-3, 5, 7-9" into inclusive
  /// (start, end) tuples.
  List<(int, int)> _parseRanges(String input, int maxPage) {
    final ranges = <(int, int)>[];
    for (final part in input.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      if (trimmed.contains('-')) {
        final pieces = trimmed.split('-');
        final start = int.tryParse(pieces[0].trim());
        final end = int.tryParse(pieces[1].trim());
        if (start != null && end != null) ranges.add((start, end));
      } else {
        final page = int.tryParse(trimmed);
        if (page != null) ranges.add((page, page));
      }
    }
    return ranges;
  }

  Future<void> _split() async {
    if (_path == null || _pageCount == null) return;
    List<(int, int)> ranges;
    if (_mode == _SplitMode.everyPage) {
      ranges = List.generate(_pageCount!, (i) => (i + 1, i + 1));
    } else {
      ranges = _parseRanges(_rangeController.text, _pageCount!);
      if (ranges.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter at least one valid page range, e.g. 1-3, 5')),
        );
        return;
      }
    }

    setState(() => _splitting = true);
    try {
      final outputs = await PdfService.splitPdf(_path!, ranges: ranges, outputName: 'Split_PDF');
      if (!mounted) return;
      final library = context.read<LibraryProvider>();
      for (final out in outputs) {
        await library.registerFile(out);
      }
      if (!mounted) return;
      setState(() => _splitting = false);
      await AppDialog.show(
        context,
        AppDialog(
          icon: Icons.check_circle_rounded,
          iconColor: AppColors.pdfPrimary,
          title: '${outputs.length} file${outputs.length == 1 ? '' : 's'} created',
          message: 'Your split PDF pages are saved to Recent PDFs.',
          confirmLabel: 'Share all',
          cancelLabel: 'Done',
          onConfirm: () async {
            for (final out in outputs) {
              await FileService.shareFile(out);
            }
          },
        ),
      );
    } on PdfOperationException catch (e) {
      setState(() => _splitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _splitting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong splitting this PDF.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Split PDF', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _path == null
              ? EmptyStateView(
                  icon: Icons.call_split_rounded,
                  title: 'No PDF selected',
                  message: 'Choose a PDF to split into individual pages or custom ranges.',
                  actionLabel: 'Choose PDF',
                  onAction: _pickPdf,
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.pdfPrimary),
                        title: Text(_path!.split(Platform.pathSeparator).last,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('$_pageCount pages'),
                        trailing: TextButton(onPressed: _pickPdf, child: const Text('Change')),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text('Split mode', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                    RadioListTile<_SplitMode>(
                      contentPadding: EdgeInsets.zero,
                      value: _SplitMode.everyPage,
                      groupValue: _mode,
                      title: const Text('Split every page into its own PDF'),
                      onChanged: (v) => setState(() => _mode = v!),
                    ),
                    RadioListTile<_SplitMode>(
                      contentPadding: EdgeInsets.zero,
                      value: _SplitMode.customRange,
                      groupValue: _mode,
                      title: const Text('Custom page ranges'),
                      onChanged: (v) => setState(() => _mode = v!),
                    ),
                    if (_mode == _SplitMode.customRange)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 8),
                        child: TextField(
                          controller: _rangeController,
                          decoration: InputDecoration(
                            hintText: 'e.g. 1-3, 5, 7-9',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    const Spacer(),
                    PrimaryButton(
                      label: _splitting ? 'Splitting…' : 'Split PDF',
                      icon: Icons.call_split_rounded,
                      loading: _splitting,
                      onPressed: _split,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
