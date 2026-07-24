import 'package:flutter/material.dart';
import 'open_source_licenses_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/list_tiles.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('About', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Center(
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6D5BF5)]),
                      boxShadow: AppColors.cardShadow(theme.brightness),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text('PDF Master Tools', style: AppTextStyles.title(theme.colorScheme.onSurface)),
                  const SizedBox(height: 4),
                  Text('Version 1.0.0 (Build 1)', style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'PDF Master Tools is an all-in-one PDF solution that helps you scan, edit, merge, split, compress, convert and organize PDF documents with speed, simplicity and privacy.',
              style: AppTextStyles.bodyLarge(theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  SettingsTile(
                    icon: Icons.code_rounded,
                    title: 'Open-source licenses',
                    onTap: () => showLicensePage(
                      context: context,
                      applicationName: 'PDF Master Tools',
                      applicationVersion: 'Version 1.0.0 (Build 1)',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('© 2026 PDF Master Tools. All rights reserved.',
                textAlign: TextAlign.center, style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Text(
              'Built with ❤️ in Pakistan',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall(theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
