import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Centralized local persistence layer.
///
/// Wraps [SharedPreferences] with typed helpers for the pieces of app
/// state that must survive restarts: settings, favorites, recent files,
/// and per-feature history (OCR / QR). All list-shaped data is stored as
/// a JSON string under a single key per bucket so reads/writes stay O(1)
/// SharedPreferences calls rather than one call per item.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sp async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  /// Must be called once (e.g. in `main()`) before first use so that
  /// synchronous getters used during widget build have data ready.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---------------------------------------------------------------------
  // Generic key/value helpers
  // ---------------------------------------------------------------------

  Future<bool> setString(String key, String value) async => (await _sp).setString(key, value);
  String? getString(String key) => _prefs?.getString(key);

  Future<bool> setBool(String key, bool value) async => (await _sp).setBool(key, value);
  bool getBool(String key, {bool defaultValue = false}) => _prefs?.getBool(key) ?? defaultValue;

  Future<bool> setInt(String key, int value) async => (await _sp).setInt(key, value);
  int getInt(String key, {int defaultValue = 0}) => _prefs?.getInt(key) ?? defaultValue;

  Future<bool> remove(String key) async => (await _sp).remove(key);

  // ---------------------------------------------------------------------
  // JSON list buckets (favorites / recents / history)
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> items) async {
    (await _sp).setString(key, jsonEncode(items));
  }

  List<Map<String, dynamic>> readBucket(String bucketKey) => _readList(bucketKey);

  Future<void> writeBucket(String bucketKey, List<Map<String, dynamic>> items) =>
      _writeList(bucketKey, items);

  /// Inserts [item] at the head of the bucket, de-duplicating by [idKey],
  /// and truncates to [maxItems].
  Future<List<Map<String, dynamic>>> pushToBucket(
    String bucketKey,
    Map<String, dynamic> item, {
    String idKey = 'id',
    int maxItems = 50,
  }) async {
    final items = _readList(bucketKey);
    items.removeWhere((e) => e[idKey] == item[idKey]);
    items.insert(0, item);
    final trimmed = items.length > maxItems ? items.sublist(0, maxItems) : items;
    await _writeList(bucketKey, trimmed);
    return trimmed;
  }

  Future<List<Map<String, dynamic>>> removeFromBucket(
    String bucketKey,
    String id, {
    String idKey = 'id',
  }) async {
    final items = _readList(bucketKey);
    items.removeWhere((e) => e[idKey] == id);
    await _writeList(bucketKey, items);
    return items;
  }

  Future<void> clearBucket(String bucketKey) => _writeList(bucketKey, const []);
}

/// Bucket key constants so every provider/service reads and writes the
/// same storage slot instead of hand-typing strings that can drift.
class StoreKeys {
  StoreKeys._();

  static const themeMode = 'settings.themeMode';
  static const biometricLock = 'settings.biometricLock';
  static const autoBackup = 'settings.autoBackup';
  static const defaultScanQuality = 'settings.defaultScanQuality';
  static const onboardingComplete = 'settings.onboardingComplete';

  static const recentFiles = 'library.recentFiles';
  static const favoriteFiles = 'library.favoriteFiles';

  static const ocrHistory = 'history.ocr';
  static const qrHistory = 'history.qr';
}
