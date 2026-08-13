/// A record of a tool run, shown in that tool's own history list.
/// Deleting a history entry only removes this record — the underlying
/// saved file (tracked separately as a [DocumentItem]) is untouched.
class ToolHistoryEntry {
  final String id;
  final String toolId;
  final String title;
  final String? resultDocumentId;
  final DateTime createdAt;
  final bool success;
  final String? note;

  const ToolHistoryEntry({
    required this.id,
    required this.toolId,
    required this.title,
    required this.createdAt,
    required this.success,
    this.resultDocumentId,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'toolId': toolId,
        'title': title,
        'resultDocumentId': resultDocumentId,
        'createdAt': createdAt.toIso8601String(),
        'success': success,
        'note': note,
      };

  factory ToolHistoryEntry.fromMap(Map map) => ToolHistoryEntry(
        id: map['id'] as String,
        toolId: map['toolId'] as String,
        title: map['title'] as String,
        resultDocumentId: map['resultDocumentId'] as String?,
        createdAt: DateTime.parse(map['createdAt'] as String),
        success: map['success'] as bool? ?? true,
        note: map['note'] as String?,
      );
}
