import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

/// Section header used across dashboard/tool screens ("Recent Files",
/// "Favorite Tools", etc.) with an optional "See all" action.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onActionTap;

  const SectionHeader({super.key, required this.title, this.actionLabel, this.onActionTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.title(theme.colorScheme.onSurface)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onActionTap,
            child: Text(actionLabel!, style: AppTextStyles.label(theme.colorScheme.primary)),
          ),
      ],
    );
  }
}

/// Settings row: leading icon, title, optional subtitle, and trailing
/// widget (chevron, switch, value text).
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: iconColor ?? theme.colorScheme.onSurface),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                  if (subtitle != null)
                    Text(subtitle!, style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// File row for Recent Files / File Manager lists.
class FileListTile extends StatelessWidget {
  final String name;
  final String meta; // e.g. "2.4 MB · 2 days ago"
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;
  final bool isFavorite;

  const FileListTile({
    super.key,
    required this.name,
    required this.meta,
    this.icon = Icons.picture_as_pdf_rounded,
    this.iconColor = const Color(0xFF4F46E5),
    this.iconBg = const Color(0xFFE8E6FD),
    this.onTap,
    this.onMoreTap,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyLarge(theme.colorScheme.onSurface)),
                  Text(meta, style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            if (isFavorite)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.star_rounded, color: Color(0xFFF5A623), size: 18),
              ),
            IconButton(
              onPressed: onMoreTap,
              icon: Icon(Icons.more_vert_rounded, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
