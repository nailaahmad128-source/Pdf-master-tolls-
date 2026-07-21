import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = [
    (
      'Information We Collect',
      'Placeholder copy — describe exactly what the shipped app collects (e.g. device identifiers, '
          'crash logs, optional account email) before release.',
    ),
    (
      'How We Use Your Files',
      'Documents you scan or edit are processed to deliver the feature you requested. Replace this with your '
          'real storage and processing policy.',
    ),
    (
      'Third-Party Services',
      'List any analytics, ad, or cloud-storage SDKs actually integrated (e.g. AdMob) and link their policies.',
    ),
    (
      'Data Retention & Deletion',
      'Explain how long files and account data are kept, and how a user can request deletion.',
    ),
    (
      'Your Rights',
      'Describe applicable regional rights (GDPR/CCPA, etc.) and how to exercise them.',
    ),
    (
      'Contact Us',
      'Provide a real support email before publishing to app stores.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Privacy Policy', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            Text('Last updated: July 19, 2026', style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            for (final (title, body) in _sections) ...[
              Text(title, style: AppTextStyles.title(theme.colorScheme.onSurface)),
              const SizedBox(height: 8),
              Text(body, style: AppTextStyles.bodyLarge(theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: 22),
            ],
          ],
        ),
      ),
    );
  }
}
