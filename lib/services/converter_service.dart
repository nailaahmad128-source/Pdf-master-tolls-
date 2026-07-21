import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/storage/local_store.dart';

enum UnitCategory { length, weight, area, volume, temperature, speed }

/// Offline unit conversion (no network needed) plus live currency rates
/// with a locally cached fallback for when the device is offline.
class ConverterService {
  ConverterService._();

  static const Map<UnitCategory, Map<String, double>> _factorsToBase = {
    // Base unit: meter
    UnitCategory.length: {
      'Meter': 1.0,
      'Kilometer': 1000.0,
      'Centimeter': 0.01,
      'Millimeter': 0.001,
      'Mile': 1609.344,
      'Yard': 0.9144,
      'Foot': 0.3048,
      'Inch': 0.0254,
    },
    // Base unit: kilogram
    UnitCategory.weight: {
      'Kilogram': 1.0,
      'Gram': 0.001,
      'Milligram': 0.000001,
      'Pound': 0.45359237,
      'Ounce': 0.028349523125,
      'Ton (metric)': 1000.0,
    },
    // Base unit: square meter
    UnitCategory.area: {
      'Square Meter': 1.0,
      'Square Kilometer': 1000000.0,
      'Square Foot': 0.09290304,
      'Acre': 4046.8564224,
      'Hectare': 10000.0,
    },
    // Base unit: liter
    UnitCategory.volume: {
      'Liter': 1.0,
      'Milliliter': 0.001,
      'Gallon (US)': 3.785411784,
      'Cup': 0.2365882365,
      'Cubic Meter': 1000.0,
    },
    // Base unit: meters/second
    UnitCategory.speed: {
      'Meters/second': 1.0,
      'Kilometers/hour': 0.277778,
      'Miles/hour': 0.44704,
      'Knots': 0.514444,
    },
  };

  static Map<String, double> unitsFor(UnitCategory category) =>
      category == UnitCategory.temperature ? const {'Celsius': 1, 'Fahrenheit': 1, 'Kelvin': 1} : _factorsToBase[category]!;

  static double convertUnit(UnitCategory category, String from, String to, double value) {
    if (category == UnitCategory.temperature) {
      return _convertTemperature(from, to, value);
    }
    final factors = _factorsToBase[category]!;
    final base = value * (factors[from] ?? 1);
    return base / (factors[to] ?? 1);
  }

  static double _convertTemperature(String from, String to, double value) {
    double celsius;
    switch (from) {
      case 'Fahrenheit':
        celsius = (value - 32) * 5 / 9;
        break;
      case 'Kelvin':
        celsius = value - 273.15;
        break;
      default:
        celsius = value;
    }
    switch (to) {
      case 'Fahrenheit':
        return celsius * 9 / 5 + 32;
      case 'Kelvin':
        return celsius + 273.15;
      default:
        return celsius;
    }
  }

  // ---------------------------------------------------------------------
  // Currency (live, with cached fallback)
  // ---------------------------------------------------------------------

  static const List<String> currencies = ['USD', 'EUR', 'GBP', 'JPY', 'PKR', 'INR', 'AED', 'CAD', 'AUD', 'CNY'];

  /// Fetches the current rate for 1 unit of [from] in [to], caching the
  /// full rate table for [from] locally so conversions keep working
  /// offline (using the last successfully fetched rates).
  ///
  /// Uses the frankfurter.dev v2 endpoint rather than the older
  /// frankfurter.app v1 one: v1 only covers ~31 ECB-published currencies
  /// and is missing several in this app's list (PKR, AED among them),
  /// while v2 covers 165+. v2 also returns a different shape -- a JSON
  /// array of `{date, base, quote, rate}` objects instead of v1's
  /// `{"rates": {...}}` map -- so the parsing below is shaped for that.
  static Future<CurrencyRateResult> getRate(String from, String to) async {
    final cacheKey = 'converter.rates.$from';
    try {
      final response = await http
          .get(Uri.parse('https://api.frankfurter.dev/v2/rates?base=$from'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as List<dynamic>;
        final rates = <String, double>{
          for (final entry in decoded.cast<Map<String, dynamic>>())
            entry['quote'] as String: (entry['rate'] as num).toDouble(),
        };
        await LocalStore.instance.setString(
          cacheKey,
          jsonEncode({'rates': rates, 'fetchedAt': DateTime.now().toIso8601String()}),
        );
        final rate = from == to ? 1.0 : rates[to];
        if (rate != null) {
          return CurrencyRateResult(rate: rate, isLive: true, fetchedAt: DateTime.now());
        }
      }
    } catch (_) {
      // fall through to cache below
    }

    final cached = LocalStore.instance.getString(cacheKey);
    if (cached != null) {
      final decoded = jsonDecode(cached) as Map<String, dynamic>;
      final rates = (decoded['rates'] as Map<String, dynamic>);
      final fetchedAt = DateTime.tryParse(decoded['fetchedAt'] as String? ?? '') ?? DateTime.now();
      final rate = from == to ? 1.0 : (rates[to] as num?)?.toDouble();
      if (rate != null) {
        return CurrencyRateResult(rate: rate, isLive: false, fetchedAt: fetchedAt);
      }
    }

    throw StateError('No internet connection and no cached rate available for $from → $to.');
  }
}

class CurrencyRateResult {
  final double rate;
  final bool isLive;
  final DateTime fetchedAt;
  const CurrencyRateResult({required this.rate, required this.isLive, required this.fetchedAt});
}
