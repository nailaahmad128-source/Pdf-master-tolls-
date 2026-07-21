import 'package:flutter/material.dart';
import '../models/tool_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';

/// Grid tool card used across Home and category screens.
/// Purely presentational — [onTap] is left for the caller to wire up.
class ToolCard extends StatefulWidget {
  final ToolItem item;
  final VoidCallback? onTap;

  const ToolCard({super.key, required this.item, this.onTap});

  @override
  State<ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<ToolCard> with SingleTickerProviderStateMixin {
  double _scale = 1;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.96 : 1);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = categoryPalette(widget.item.category);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppColors.cardShadow(theme.brightness, tint: palette.primary),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              splashColor: palette.primary.withOpacity(0.12),
              highlightColor: palette.primary.withOpacity(0.06),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          palette.primary,
                          palette.primary.withOpacity(0.75),
                        ],
                      ),
                    ),
                    child: Icon(widget.item.icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    widget.item.title,
                    style: AppTextStyles.subtitle(theme.colorScheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.subtitle,
                    style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              if (widget.item.isNew)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.accentCoralSoft.withOpacity(0.2) : AppColors.accentCoralSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('NEW', style: AppTextStyles.overline(AppColors.accentCoral)),
                  ),
                ),
            ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
