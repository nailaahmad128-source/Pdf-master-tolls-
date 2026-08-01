import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';
import 'app_buttons.dart';

/// Rounded pill search field with a leading icon and optional filter action.
class AppSearchBar extends StatelessWidget {
  final String hint;
  final VoidCallback? onFilterTap;
  final ValueChanged<String>? onChanged;

  const AppSearchBar({
    super.key,
    this.hint = 'Search tools, files…',
    this.onFilterTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: TextField(
            onChanged: onChanged,
            style: AppTextStyles.bodyMedium(theme.colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ),
        if (onFilterTap != null) ...[
          const SizedBox(width: 10),
          CircleIconButton(icon: Icons.tune_rounded, onPressed: onFilterTap),
        ],
      ],
    );
  }
}

/// Home dashboard app bar: greeting, avatar, notification bell.
class HomeAppBar extends StatelessWidget {
  final String userName;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationTap;

  const HomeAppBar({
    super.key,
    this.userName = 'Alex',
    this.onAvatarTap,
    this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : (hour < 18 ? 'Good afternoon' : 'Good evening');

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)]),
            ),
            child: const Icon(Icons.person_rounded, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
              Text(userName, style: AppTextStyles.title(theme.colorScheme.onSurface)),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            CircleIconButton(icon: Icons.notifications_none_rounded, onPressed: onNotificationTap),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 1.6),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
