import 'dart:convert';

/// One audit log entry as the owner reads it (P3-07).
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.action,
    required this.target,
    required this.by,
    this.byEmail,
    this.at,
    this.before,
    required this.after,
  });

  final String id;
  final String action;
  final String target;
  final String by;
  final String? byEmail;
  final DateTime? at;
  final Map<String, dynamic>? before;
  final Map<String, dynamic> after;

  /// Fields that changed: key -> (before, after), as readable text. A new
  /// document lists every field.
  Map<String, (String?, String)> get changes {
    String show(Object? v) => v is String ? v : jsonEncode(v);
    final out = <String, (String?, String)>{};
    for (final e in after.entries) {
      final was = before?[e.key];
      if (before == null || jsonEncode(was) != jsonEncode(e.value)) {
        out[e.key] = (before == null ? null : show(was), show(e.value));
      }
    }
    for (final k in before?.keys ?? const <String>[]) {
      if (!after.containsKey(k)) out[k] = (show(before![k]), '—');
    }
    return out;
  }
}
