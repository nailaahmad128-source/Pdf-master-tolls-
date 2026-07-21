import 'package:flutter/foundation.dart';

/// A single row in a feature's history log (OCR extraction or QR
/// scan/generate event). Kept intentionally generic — [title] is the
/// headline text (extracted text snippet, or QR payload), [subtitle]
/// carries secondary info (language used, or QR type), and [payload]
/// holds the full content for re-opening/copying later.
@immutable
class HistoryEntry {
  final String id;
  final String title;
  final String subtitle;
  final String payload;
  final DateTime createdAt;

  const HistoryEntry({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.payload,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        title: json['title'] as String,
        subtitle: json['subtitle'] as String? ?? '',
        payload: json['payload'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );
}
