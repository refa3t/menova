import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_access.dart';
import '../domain/draft.dart';

/// Every pending draft, newest first, live (P3-09).
final draftsProvider = StreamProvider<List<Draft>>(
  (ref) => FirebaseFirestore.instance
      .collection('drafts')
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (DraftKind.ofTarget(d['target'] as String) case final kind?)
              Draft(
                target: d['target'] as String,
                kind: kind,
                changes: (d['changes'] as Map).cast<String, dynamic>(),
                base: (d.data()['base'] as Map?)?.cast<String, dynamic>(),
                isNew: d.data()['isNew'] as bool? ?? false,
                by: d.data()['by'] as String?,
                byEmail: d.data()['byEmail'] as String?,
                at: (d.data()['at'] as Timestamp?)?.toDate(),
              ),
        ]..sort((a, b) => (b.at ?? DateTime(0)).compareTo(a.at ?? DateTime(0))),
      ),
);

/// Saves and drops drafts. Publishing goes through the audited writer.
class DraftWriter {
  DraftWriter(this._db);

  final FirebaseFirestore _db;

  /// Saves [edited] as the draft of [target], or drops the draft when it
  /// matches the live record ([live] null for a new record).
  Future<void> save({
    required Granted who,
    required DraftKind kind,
    required String target,
    required Json? live,
    required Json edited,
  }) {
    final ref = _db.collection('drafts').doc(draftIdFor(target));
    final d = diffRecord(live, edited);
    if (d.changes.isEmpty) return ref.delete();
    return ref.set({
      'target': target,
      'kind': kind.name,
      'isNew': live == null,
      'changes': d.changes,
      'base': d.base,
      'by': who.uid,
      'byEmail': ?who.email,
      'at': FieldValue.serverTimestamp(),
    });
  }

  Future<void> discard(Draft d) => _db.collection('drafts').doc(d.id).delete();
}

final draftWriterProvider = Provider<DraftWriter>(
  (ref) => DraftWriter(FirebaseFirestore.instance),
);
