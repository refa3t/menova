import 'package:core/core.dart';

/// What a draft can change (P3-09, owner choice: products and ingredient
/// prices).
enum DraftKind {
  product('products'),
  ingredient('ingredients');

  const DraftKind(this.collection);
  final String collection;

  static DraftKind? ofTarget(String target) {
    for (final k in values) {
      if (target.startsWith('${k.collection}/')) return k;
    }
    return null;
  }
}

/// A change to one product or ingredient saved for later (P3-09): only the
/// fields that differ from the live record, with their live values at the
/// time. Customers see nothing until an admin publishes it.
class Draft {
  const Draft({
    required this.target,
    required this.kind,
    required this.changes,
    this.base,
    this.isNew = false,
    this.by,
    this.byEmail,
    this.at,
  });

  /// `products/{id}` or `ingredients/{id}`.
  final String target;
  final DraftKind kind;

  /// New values of the changed fields (the whole record when [isNew]).
  final Json changes;

  /// The live values of those fields when the draft was saved.
  final Json? base;
  final bool isNew;
  final String? by;
  final String? byEmail;
  final DateTime? at;

  String get id => draftIdFor(target);
  String get recordId => target.substring(target.indexOf('/') + 1);

  /// The record once published: the live one with the changes on top, so
  /// fields changed live meanwhile (availability) are kept.
  Json applyTo(Json? live) => {...?live, ...changes};

  /// Changed fields whose live value moved since the draft was saved:
  /// publishing replaces them.
  List<String> conflictsWith(Json? live) => [
    if (base case final b?)
      for (final k in changes.keys)
        if (b.containsKey(k) && !jsonEquals(live?[k], b[k])) k,
  ];
}

/// One draft per record: its document id.
String draftIdFor(String target) => target.replaceAll('/', '__');

/// The fields of [edited] that differ from [live] (every field for a new
/// record), and the live values of those fields.
({Json changes, Json? base}) diffRecord(Json? live, Json edited) {
  if (live == null) return (changes: edited, base: null);
  final changes = <String, dynamic>{
    for (final e in edited.entries)
      if (!jsonEquals(live[e.key], e.value)) e.key: e.value,
  };
  return (changes: changes, base: {for (final k in changes.keys) k: live[k]});
}

/// Deep equality of JSON values; map key order does not matter.
bool jsonEquals(Object? a, Object? b) {
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (!b.containsKey(e.key) || !jsonEquals(e.value, b[e.key])) {
        return false;
      }
    }
    return true;
  }
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!jsonEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is num && b is num) return a == b;
  return a == b;
}
