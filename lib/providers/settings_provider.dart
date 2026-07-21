import 'package:flutter/material.dart';

import '../core/storage/local_store.dart';

/// Persisted app-wide settings, exposed via [ChangeNotifier] so any
/// widget (starting with [MaterialApp] itself) rebuilds when they change.
///
/// This does not alter any screen's layout or colors — it only makes the
/// existing Dark mode switch, biometric lock switch, auto-backup switch,
/// and scan-quality row on the Settings screen actually persist and take
/// effect, per the "Persistent Settings" requirement.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider() {
    _load();
  }

  ThemeMode _themeMode = ThemeMode.system;
  bool _biometricLock = false;
  bool _autoBackup = true;
  String _defaultScanQuality = 'HD';
  String _appLanguage = 'English';

  ThemeMode get themeMode => _themeMode;
  bool get biometricLock => _biometricLock;
  bool get autoBackup => _autoBackup;
  String get defaultScanQuality => _defaultScanQuality;
  String get appLanguage => _appLanguage;

  void _load() {
    final storedTheme = LocalStore.instance.getString(StoreKeys.themeMode);
    _themeMode = switch (storedTheme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _biometricLock = LocalStore.instance.getBool(StoreKeys.biometricLock);
    _autoBackup = LocalStore.instance.getBool(StoreKeys.autoBackup, defaultValue: true);
    _defaultScanQuality = LocalStore.instance.getString(StoreKeys.defaultScanQuality) ?? 'HD';
    _appLanguage = LocalStore.instance.getString(StoreKeys.appLanguage) ?? 'English';
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await LocalStore.instance.setString(StoreKeys.themeMode, mode.name);
  }

  /// Convenience for the existing boolean "Dark mode" switch: `true` maps
  /// to [ThemeMode.dark], `false` maps to [ThemeMode.light] (an explicit
  /// choice rather than system, matching a manual toggle's intent).
  bool get isDarkModeOn => _themeMode == ThemeMode.dark;
  Future<void> setDarkModeOn(bool value) => setThemeMode(value ? ThemeMode.dark : ThemeMode.light);

  Future<void> setBiometricLock(bool value) async {
    _biometricLock = value;
    notifyListeners();
    await LocalStore.instance.setBool(StoreKeys.biometricLock, value);
  }

  Future<void> setAutoBackup(bool value) async {
    _autoBackup = value;
    notifyListeners();
    await LocalStore.instance.setBool(StoreKeys.autoBackup, value);
  }

  Future<void> setDefaultScanQuality(String value) async {
    _defaultScanQuality = value;
    notifyListeners();
    await LocalStore.instance.setString(StoreKeys.defaultScanQuality, value);
  }

  Future<void> setAppLanguage(String value) async {
    _appLanguage = value;
    notifyListeners();
    await LocalStore.instance.setString(StoreKeys.appLanguage, value);
  }
}
