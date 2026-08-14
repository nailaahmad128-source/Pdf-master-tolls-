import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/services/file_storage_service.dart';
import '../../../core/widgets/document_tile.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../../models/document_item.dart';
import '../../reader/screens/pdf_reader_screen.dart';

enum _LibraryFilter { all, pdf, image, favorites }

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  String _query = '';

  Future<void> _importFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      allowMultiple: true,
    );
    if (result == null || !mounted) return;
    final storage = context.read<FileStorageService>();
    final data = context.read<AppDataController>();
    for (final f in result.files) {
      if (f.path == null) continue;
      final copied = await storage.importIntoLibrary(File(f.path!), preferredName: f.name);
      final size = await storage.fileSize(copied);
      final doc = DocumentItem(
        id: storage.newId(),
        name: f.name,
        filePath: copied,
        sizeBytes: size,
        createdAt: DateTime.now(),
        modifiedAt: DateTime.now(),
        type: 'pdf',
      );
      await data.addDocument(doc);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported ${result.files.length} file(s)')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    var docs = data.documents;

    docs = switch (_filter) {
      _LibraryFilter.all => docs,
      _LibraryFilter.pdf => docs.where((d) => d.type == 'pdf').toList(),
      _LibraryFilter.image => docs.where((d) => d.type == 'image').toList(),
      _LibraryFilter.favorites => docs.where((d) => d.isFavorite).toList(),
    };
    if (_query.isNotEmpty) {
      docs = docs.where((d) => d.name.toLowerCase().contains(_query.toLowerCase())).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file_rounded),
            tooltip: 'Import PDF',
            onPressed: _importFiles,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search your files',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _FilterChip(label: 'All', selected: _filter == _LibraryFilter.all,
                      onTap: () => setState(() => _filter = _LibraryFilter.all)),
                  _FilterChip(label: 'PDFs', selected: _filter == _LibraryFilter.pdf,
                      onTap: () => setState(() => _filter = _LibraryFilter.pdf)),
                  _FilterChip(label: 'Images', selected: _filter == _LibraryFilter.image,
                      onTap: () => setState(() => _filter = _LibraryFilter.image)),
                  _FilterChip(label: 'Favorites', selected: _filter == _LibraryFilter.favorites,
                      onTap: () => setState(() => _filter = _LibraryFilter.favorites)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: docs.isEmpty
                  ? EmptyState(
                      icon: Icons.folder_open_rounded,
                      title: data.documents.isEmpty ? 'Your Library is empty' : 'No matches',
                      message: data.documents.isEmpty
                          ? 'Files you create with tools are saved here automatically. You can also import your own PDFs.'
                          : 'Try a different search or filter.',
                      action: data.documents.isEmpty
                          ? FilledButton.icon(
                              onPressed: _importFiles,
                              icon: const Icon(Icons.upload_file_rounded),
                              label: const Text('Import a PDF'),
                            )
                          : null,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final doc = docs[i];
                        return DocumentTile(
                          doc: doc,
                          onTap: () {
                            if (doc.type == 'pdf') {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (_) => PdfReaderScreen(doc: doc)));
                            } else {
                              OpenFilex.open(doc.filePath);
                            }
                          },
                          onDelete: () => data.deleteDocument(doc.id),
                          onToggleFavorite: () => data.toggleFavorite(doc.id),
                        );
                      },
                    ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()),
    );
  }
}
