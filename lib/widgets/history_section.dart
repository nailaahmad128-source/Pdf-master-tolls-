import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/history_entry.dart';
import '../theme/app_text_styles.dart';
import 'creation_flow.dart';

/// Renders a titled list of [HistoryEntry] rows with an optional "Clear"
/// action. Every tool (Merge, Split, Compress, PDF to Image, Image to
/// PDF, QR Scanner, QR Generator, ...) owns its own bucket in
/// [LocalStore] and passes its own entries here — this widget never
/// mixes histories from different tools.
///
/// When [historyBucketKey] is provided, each entry is rendered as a
/// [FileHistoryCard] (a real output file, with Open/Share/More actions)
/// instead of the plain tap-to-reuse row -- used by every tool whose
/// history entries point at files it created (Merge, Split, Compress,
/// PDF to Image, Image to PDF). Tools whose history is non-file content
/// (OCR text, QR payload) keep the original simple row by omitting it.
class HistorySection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<HistoryEntry> entries;
  final String emptyMessage;
  final VoidCallback? onClear;
  final ValueChanged<HistoryEntry>? onTapEntry;
  final String? historyBucketKey;
  final VoidCallback? onEntryChanged;

  const HistorySection({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
    required this.emptyMessage,
    this.onClear,
    this.onTapEntry,
    this.historyBucketKey,
    this.onEntryChanged,
  });

  static String relativeDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return DateFormat.yMMMd().format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: AppTextStyles.title(theme.colorScheme.onSurface)),
            if (entries.isNotEmpty && onClear != null)
              TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        const SizedBox(height: 4),
        if (entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyMessage, style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
          )
        else if (historyBucketKey != null)
          ...entries.map(
            (h) => FileHistoryCard(
              entry: h,
              icon: icon,
              color: color,
              historyBucketKey: historyBucketKey!,
              onChanged: onEntryChanged,
            ),
          )
        else
          ...entries.map(
            (h) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: onTapEntry == null ? null : () => onTapEntry!(h),
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
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(h.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                              if (h.subtitle.isNotEmpty)
                                Text(h.subtitle, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Text(relativeDate(h.createdAt), style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
