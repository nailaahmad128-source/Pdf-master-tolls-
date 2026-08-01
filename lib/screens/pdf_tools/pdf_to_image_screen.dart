import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/storage/local_store.dart';
import '../../models/history_entry.dart';
import '../../providers/library_provider.dart';
import '../../services/pdf_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/creation_flow.dart';
import '../../widgets/history_section.dart';
import '../../widgets/state_views.dart';

class PdfToImageScreen extends StatefulWidget {
  const PdfToImageScreen({super.key});

  @override
  State<PdfToImageScreen> createState() => _PdfToImageScreenState();
}

class _PdfToImageScreenState extends State<PdfToImageScreen> {
  String? _path;
  int? _pageCount;
  String _format = 'PNG';
  double _dpi = 200;
  bool _exporting = false;
  List<HistoryEntry> _history = [];

  @override
  void initState() {
    super.initState();
    _history = _readHistory();
  }

  List<HistoryEntry> _readHistory() =>
      LocalStore.instance.readBucket(StoreKeys.pdfToImageHistory).map(HistoryEntry.fromJson).toList();

  Future<void> _saveToHistory(String sourceName, List<String> outputPaths, int pageCount, String format) async {
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: sourceName,
      subtitle: '$pageCount $format page${pageCount == 1 ? '' : 's'}',
      payload: outputPaths.join(HistoryEntry.pathDelimiter),
      createdAt: DateTime.now(),
    );
    await LocalStore.instance.pushToBucket(StoreKeys.pdfToImageHistory, entry.toJson(), maxItems: 100);
    if (!mounted) return;
    setState(() => _history = _readHistory());
  }

  Future<void> _clearHistory() async {
    await LocalStore.instance.clearBucket(StoreKeys.pdfToImageHistory);
    setState(() => _history = []);
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

  Future<void> _export() async {
    if (_path == null || _exporting) return; // Prevent double tapping / duplicate creation.
    setState(() => _exporting = true);
    final sourceName = _path!.split(Platform.pathSeparator).last;
    try {
      await runCreationFlow<List<String>>(
        context: context,
        loadingTitle: 'Exporting pages…',
        loadingSubtitle: 'Turning "$sourceName" into $_format images.',
        task: () async {
          final pages = await PdfService.pdfToImages(
            _path!,
            dpi: _dpi,
            format: _format == 'PNG' ? ImageExportFormat.png : ImageExportFormat.jpg,
            outputName: 'Page',
          );
          final library = context.read<LibraryProvider>();
          final paths = <String>[];
          for (final page in pages) {
            await library.registerFile(page.path);
            paths.add(page.path);
          }
          await _saveToHistory(sourceName, paths, pages.length, _format);
          return paths;
        },
      );
      if (!mounted) return;
      setState(() => _exporting = false);
    } on PdfOperationException catch (e) {
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _exporting = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Something went wrong exporting these pages.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('PDF to Image', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: _path == null
              ? ListView(
                  children: [
                    EmptyStateView(
                      icon: Icons.photo_library_rounded,
                      title: 'No PDF selected',
                      message: 'Choose a PDF to export its pages as JPG or PNG images.',
                      actionLabel: 'Choose PDF',
                      onAction: _pickPdf,
                    ),
                    const SizedBox(height: 24),
                    HistorySection(
                      title: 'PDF to Image History',
                      icon: Icons.photo_library_rounded,
                      color: AppColors.pdfPrimary,
                      entries: _history,
                      emptyMessage: 'PDFs you export as images will show up here.',
                      onClear: _clearHistory,
                      historyBucketKey: StoreKeys.pdfToImageHistory,
                      onEntryChanged: () => setState(() => _history = _readHistory()),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
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
                            Row(
                              children: [
                                Text('Format', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                                const Spacer(),
                                DropdownButton<String>(
                                  value: _format,
                                  underline: const SizedBox.shrink(),
                                  items:
                                      ['PNG', 'JPG'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                                  onChanged: (v) => setState(() => _format = v!),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Quality (DPI)', style: AppTextStyles.subtitle(theme.colorScheme.onSurface)),
                            Slider(
                              value: _dpi,
                              min: 72,
                              max: 300,
                              divisions: 4,
                              label: '${_dpi.round()} DPI',
                              onChanged: (v) => setState(() => _dpi = v),
                            ),
                            const SizedBox(height: 24),
                            HistorySection(
                              title: 'PDF to Image History',
                              icon: Icons.photo_library_rounded,
                              color: AppColors.pdfPrimary,
                              entries: _history,
                              emptyMessage: 'PDFs you export as images will show up here.',
                              onClear: _clearHistory,
                              historyBucketKey: StoreKeys.pdfToImageHistory,
                              onEntryChanged: () => setState(() => _history = _readHistory()),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: _exporting ? 'Exporting…' : 'Export $_pageCount page${_pageCount == 1 ? '' : 's'}',
                      icon: Icons.photo_library_rounded,
                      loading: _exporting,
                      onPressed: _export,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
