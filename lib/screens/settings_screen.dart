import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../providers/library_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/dialogs_and_sheets.dart';
import '../widgets/list_tiles.dart';
import 'about_screen.dart';
import 'privacy_policy_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  String _cacheSize = 'Calculating…';

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final summary = await FileService.storageSummary();
    if (!mounted) return;
    setState(() => _cacheSize = FileService.readableSize(summary.usedBytes));
  }

  Future<void> _confirmClearCache() async {
    await AppDialog.show(
      context,
      AppDialog(
        icon: Icons.delete_sweep_rounded,
        iconColor: AppColors.error,
        title: 'Clear all app files?',
        message:
            'This permanently deletes every scan, merged/split/compressed PDF, signed document, and OCR '
            'export stored in PDF Master Tools ($_cacheSize). Files already shared or saved elsewhere are '
            'not affected. This cannot be undone.',
        confirmLabel: 'Delete all',
        cancelLabel: 'Cancel',
        destructive: true,
        onConfirm: _clearCache,
      ),
    );
  }

  Future<void> _clearCache() async {
    final files = await FileService.listAll();
    for (final f in files) {
      await FileService.delete(f.path);
    }
    if (mounted) {
      await context.read<LibraryProvider>().clearAll();
    }
    await _loadCacheSize();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cache cleared.')));
  }


  Future<void> _toggleBiometric(bool enable) async {
    final settings = context.read<SettingsProvider>();

    if (!enable) {
      await settings.setBiometricLock(false);
      return;
    }

    try {
      final supported = await _localAuth.isDeviceSupported();
      final canCheck = await _localAuth.canCheckBiometrics;

      if (!supported || !canCheck) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Biometric authentication is not available on this device.'),
          ),
        );
        return;
      }

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to enable app lock',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      await settings.setBiometricLock(authenticated);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometric authentication failed.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: Text('Settings', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          children: [
            // Profile summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF6D5BF5)]),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                    child: const Icon(Icons.person_rounded, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Alex Morgan', style: AppTextStyles.title(Colors.white)),
                        Text('Free plan · 3 of 5 tools/day', style: AppTextStyles.bodySmall(Colors.white.withOpacity(0.85))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Text('Upgrade', style: AppTextStyles.label(AppColors.brandIndigo)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SettingsGroup(
              title: 'Preferences',
              children: [
                SettingsTile(
                  icon: Icons.dark_mode_rounded,
                  title: 'Dark mode',
                  subtitle: settings.themeMode == ThemeMode.system
                      ? 'Following system'
                      : (settings.isDarkModeOn ? 'On' : 'Off'),
                  trailing: Switch(
                    value: settings.isDarkModeOn,
                    onChanged: (v) => settings.setDarkModeOn(v),
                  ),
                ),
                SettingsTile(
                  icon: Icons.language_rounded,
                  title: 'App language',
                  subtitle: settings.appLanguage,
                  onTap: () => _showChoiceSheet(
                    title: 'App language',
                    options: const ['English', 'Urdu', 'Arabic'],
                    current: settings.appLanguage,
                    onSelected: settings.setAppLanguage,
                  ),
                ),
                SettingsTile(
                  icon: Icons.high_quality_rounded,
                  title: 'Default scan quality',
                  subtitle: settings.defaultScanQuality,
                  onTap: () => _showChoiceSheet(
                    title: 'Default scan quality',
                    options: const ['Standard', 'HD', 'Ultra HD'],
                    current: settings.defaultScanQuality,
                    onSelected: settings.setDefaultScanQuality,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: 'Security & Backup',
              children: [
                SettingsTile(
                  icon: Icons.fingerprint_rounded,
                  title: 'Biometric app lock',
                  trailing: Switch(
                    value: settings.biometricLock,
                    onChanged: _toggleBiometric,
                  ),
                ),
                SettingsTile(
                  icon: Icons.cloud_upload_rounded,
                  title: 'Auto-backup files',
                  trailing: Switch(
                    value: settings.autoBackup,
                    onChanged: (v) => settings.setAutoBackup(v),
                  ),
                ),
                SettingsTile(
                  icon: Icons.delete_sweep_rounded,
                  title: 'Clear cache',
                  subtitle: _cacheSize,
                  onTap: _confirmClearCache,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SettingsGroup(
              title: 'About',
              children: [
                SettingsTile(
                  icon: Icons.info_outline_rounded,
                  title: 'About PDF Master Tools',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen())),
                ),
                SettingsTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy Policy',
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
                ),
                SettingsTile(icon: Icons.star_border_rounded, title: 'Rate the app', onTap: () {}),
                SettingsTile(icon: Icons.share_outlined, title: 'Share with friends', onTap: () {}),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showChoiceSheet({
    required String title,
    required List<String> options,
    required String current,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(title, style: AppTextStyles.title(Theme.of(ctx).colorScheme.onSurface)),
              ),
            ),
            ...options.map(
              (o) => RadioListTile<String>(
                value: o,
                groupValue: current,
                title: Text(o),
                onChanged: (v) {
                  if (v != null) onSelected(v);
                  Navigator.pop(ctx);
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SettingsGroup({required this.title, required this.children});


  

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: AppTextStyles.overline(theme.colorScheme.onSurfaceVariant)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (i) {
              if (i.isOdd) return Divider(height: 1, color: theme.colorScheme.outlineVariant);
              return children[i ~/ 2];
            }),
          ),
        ),
      ],
    );
  }
}
