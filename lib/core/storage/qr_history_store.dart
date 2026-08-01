import 'local_store.dart';
import '../../models/history_entry.dart';

/// Deprecated compatibility shim.
///
/// QR Scanner and QR Generator each now keep their own independent
/// history ([StoreKeys.qrScanHistory] / [StoreKeys.qrGeneratedHistory])
/// via plain [LocalStore] calls directly in their screens — see
/// `qr_scanner_screen.dart` and `qr_generator_screen.dart`.
///
/// This class only exists so that any leftover reference to the old
/// combined `QrHistoryStore` (from before Scanner/Generator were split
/// into separate tools) still resolves and compiles. New code should
/// not call this — read/write `StoreKeys.qrScanHistory` or
/// `StoreKeys.qrGeneratedHistory` directly instead.
@Deprecated('Use StoreKeys.qrScanHistory or StoreKeys.qrGeneratedHistory directly.')
class QrHistoryStore {
  QrHistoryStore._();

  /// Writes to the Scan History bucket. [subtitle] of 'Scanned' routes
  /// here; anything else is treated as a generated code and routes to
  /// the Generated QR History bucket instead, so old call sites that
  /// pass either kind still land in the correct, separate history.
  static Future<void> add({required String title, required String subtitle, required String payload}) async {
    final entry = HistoryEntry(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      subtitle: subtitle,
      payload: payload,
      createdAt: DateTime.now(),
    );
    final bucket = subtitle == 'Scanned' ? StoreKeys.qrScanHistory : StoreKeys.qrGeneratedHistory;
    await LocalStore.instance.pushToBucket(bucket, entry.toJson(), maxItems: 100);
  }

  /// Combined view of both histories, newest first, for any old call
  /// site that expected a single merged list.
  static List<HistoryEntry> readAll() {
    final scans = LocalStore.instance.readBucket(StoreKeys.qrScanHistory).map(HistoryEntry.fromJson);
    final generated = LocalStore.instance.readBucket(StoreKeys.qrGeneratedHistory).map(HistoryEntry.fromJson);
    final combined = [...scans, ...generated]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return combined;
  }

  static Future<void> clear() async {
    await LocalStore.instance.clearBucket(StoreKeys.qrScanHistory);
    await LocalStore.instance.clearBucket(StoreKeys.qrGeneratedHistory);
  }
}
