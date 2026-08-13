import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_config.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/utils/format_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Appearance'),
            Card(
              child: Column(
                children: [
                  RadioListTile<int>(
                    title: const Text('System default'),
                    value: 0,
                    groupValue: data.themeModeIndex,
                    onChanged: (v) => data.setThemeModeIndex(v!),
                  ),
                  RadioListTile<int>(
                    title: const Text('Light'),
                    value: 1,
                    groupValue: data.themeModeIndex,
                    onChanged: (v) => data.setThemeModeIndex(v!),
                  ),
                  RadioListTile<int>(
                    title: const Text('Dark'),
                    value: 2,
                    groupValue: data.themeModeIndex,
                    onChanged: (v) => data.setThemeModeIndex(v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('Storage'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_rounded),
                    title: const Text('Files in Library'),
                    trailing: Text('${data.documents.length}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded),
                    title: const Text('Files in Recently Deleted'),
                    trailing: Text('${data.trashItems.length}'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.storage_rounded),
                    title: const Text('Total storage used'),
                    trailing: Text(formatBytes(
                      data.documents.fold<int>(0, (a, b) => a + b.sizeBytes) +
                          data.trashItems.fold<int>(0, (a, b) => a + b.sizeBytes),
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionLabel('About'),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Version'),
                    trailing: Text(_version.isEmpty ? '—' : _version),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('Privacy Policy'),
                    subtitle: AppConfig.privacyPolicyUrl.isEmpty
                        ? const Text('Not configured yet')
                        : null,
                    enabled: AppConfig.privacyPolicyUrl.isNotEmpty,
                    trailing: AppConfig.privacyPolicyUrl.isNotEmpty
                        ? const Icon(Icons.chevron_right_rounded)
                        : null,
                    onTap: AppConfig.privacyPolicyUrl.isEmpty
                        ? null
                        : () {
                            final uri = Uri.tryParse(AppConfig.privacyPolicyUrl);
                            if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
                          },
                  ),
                  ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: const Text('Share this app'),
                    onTap: () => Share.share('Check out PDF Master Tools — every PDF tool you need in one app.'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'PDF Master Tools',
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
