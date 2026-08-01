import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Result of a permission request the UI can branch on directly.
enum PermissionOutcome { granted, denied, permanentlyDenied, restricted }

/// Central place for requesting and reasoning about runtime permissions.
///
/// Every screen that needs camera/storage/photos/notifications access
/// should go through here rather than calling `permission_handler`
/// directly, so denial handling (snackbar vs. "open settings" dialog)
/// stays consistent app-wide.
class PermissionService {
  PermissionService._();

  static Future<PermissionOutcome> _request(Permission permission) async {
    final status = await permission.status;
    if (status.isGranted || status.isLimited) return PermissionOutcome.granted;

    final result = await permission.request();
    if (result.isGranted || result.isLimited) return PermissionOutcome.granted;
    if (result.isPermanentlyDenied) return PermissionOutcome.permanentlyDenied;
    if (result.isRestricted) return PermissionOutcome.restricted;
    return PermissionOutcome.denied;
  }

  static Future<PermissionOutcome> camera() => _request(Permission.camera);

  static Future<PermissionOutcome> notifications() => _request(Permission.notification);

  /// Storage/photos access differs by platform & OS version:
  /// - Android 13+: granular `photos` (READ_MEDIA_IMAGES)
  /// - Android <13: legacy `storage`
  /// - iOS: `photos`
  /// We simply request both relevant permissions and accept either grant,
  /// since only one of the pair applies to the running OS.
  static Future<PermissionOutcome> photosOrStorage() async {
    final photos = await _request(Permission.photos);
    if (photos == PermissionOutcome.granted) return PermissionOutcome.granted;

    final storage = await _request(Permission.storage);
    if (storage == PermissionOutcome.granted) return PermissionOutcome.granted;

    // If either is permanently denied, surface that (stronger) state so the
    // caller can prompt to open Settings instead of re-requesting forever.
    if (photos == PermissionOutcome.permanentlyDenied ||
        storage == PermissionOutcome.permanentlyDenied) {
      return PermissionOutcome.permanentlyDenied;
    }
    return PermissionOutcome.denied;
  }

  /// Shows a friendly dialog when a permission is denied, with a direct
  /// path to system settings for the permanently-denied case. Returns
  /// `true` if the user ended up granting access (only meaningful for the
  /// "open settings" path — caller should re-check status after).
  static Future<bool> handleDenied(
    BuildContext context,
    PermissionOutcome outcome, {
    required String featureName,
  }) async {
    if (outcome == PermissionOutcome.granted) return true;

    if (!context.mounted) return false;

    if (outcome == PermissionOutcome.permanentlyDenied || outcome == PermissionOutcome.restricted) {
      final opened = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Permission required'),
          content: Text(
            '$featureName needs access that was previously denied. '
            'Enable it from your device Settings to continue.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx, true);
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return opened ?? false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$featureName needs permission to continue.')),
    );
    return false;
  }
}
