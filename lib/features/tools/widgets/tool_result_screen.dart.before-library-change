import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/ads_service.dart';
import '../../../core/utils/format_utils.dart';
import '../../../models/document_item.dart';

/// Shown right after a tool finishes. Kept as its own screen (rather than a
/// dialog) so the user has a clean, unhurried moment to open/share/save —
/// and so an interstitial, if one is due, has a natural, non-disruptive
/// place to appear (never mid-processing).
class ToolResultScreen extends StatefulWidget {
  final List<DocumentItem> results;
  final String successTitle;

  const ToolResultScreen({
    super.key,
    required this.results,
    this.successTitle = 'Done!',
  });

  @override
  State<ToolResultScreen> createState() => _ToolResultScreenState();
}

class _ToolResultScreenState extends State<ToolResultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AdsService>().maybeShowInterstitialAfterToolAction();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: theme.colorScheme.primary, size: 44),
              ),
              const SizedBox(height: 20),
              Text(widget.successTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 6),
              Text(
                widget.results.length == 1
                    ? 'Saved to your Library'
                    : '${widget.results.length} files saved to your Library',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: widget.results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final doc = widget.results[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          doc.type == 'image' ? Icons.image_rounded : Icons.picture_as_pdf_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(formatBytes(doc.sizeBytes)),
                        trailing: IconButton(
                          icon: const Icon(Icons.ios_share_rounded),
                          onPressed: () => Share.shareXFiles([XFile(doc.filePath)]),
                        ),
                        onTap: () => OpenFilex.open(doc.filePath),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
