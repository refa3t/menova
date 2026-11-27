import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_access.dart';
import '../domain/catalog_list.dart';

/// Every admin change is one batch: the document and its audit entry (P3-07:
/// who, what, when, before and after). Firestore rules refuse a change
/// without its entry, and the entry can never be edited or deleted.
class AuditedWriter {
  AuditedWriter(this._db);

  final FirebaseFirestore _db;

  /// [alsoDelete] goes in the same batch (the draft a publish applies).
  Future<void> write({
    required Granted who,
    required String action,
    required String path,
    required Json after,
    Json? before,
    String? alsoDelete,
  }) {
    final audit = _db.collection('auditLog').doc();
    final batch = _db.batch()
      ..set(audit, {
        'action': action,
        'target': path,
        'by': who.uid,
        'byEmail': ?who.email,
        'at': FieldValue.serverTimestamp(),
        'before': before,
        'after': after,
      })
      ..set(_db.doc(path), {...after, 'lastAuditId': audit.id});
    if (alsoDelete != null) batch.delete(_db.doc(alsoDelete));
    return batch.commit();
  }

  /// Applies [changes] in batches of [maxChangesPerBatch], each change with
  /// its own audit entry in the same batch (as [write]). A batch the server
  /// refuses is retried one change at a time, so one bad record does not
  /// stop the rest. [onProgress] gets the count of changes handled so far.
  /// Returns the paths that could not be saved.
  Future<List<String>> writeAll({
    required Granted who,
    required List<AuditedChange> changes,
    void Function(int done, int total)? onProgress,
  }) async {
    final failed = <String>[];
    var done = 0;
    for (final chunk in chunked(changes)) {
      try {
        await _batchOf(who, chunk).commit();
      } on Object {
        for (final c in chunk) {
          try {
            await _batchOf(who, [c]).commit();
          } on Object {
            failed.add(c.path);
          }
        }
      }
      done += chunk.length;
      onProgress?.call(done, changes.length);
    }
    return failed;
  }

  WriteBatch _batchOf(Granted who, List<AuditedChange> changes) {
    final batch = _db.batch();
    for (final c in changes) {
      final audit = _db.collection('auditLog').doc();
      batch
        ..set(audit, {
          'action': c.action,
          'target': c.path,
          'by': who.uid,
          'byEmail': ?who.email,
          'at': FieldValue.serverTimestamp(),
          'before': c.before,
          'after': c.after,
        })
        ..set(_db.doc(c.path), {...c.after, 'lastAuditId': audit.id});
    }
    return batch;
  }
}

final auditedWriterProvider = Provider<AuditedWriter>(
  (ref) => AuditedWriter(FirebaseFirestore.instance),
);
