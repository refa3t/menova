import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_access.dart';

/// Every admin change is one batch: the document and its audit entry (P3-07:
/// who, what, when, before and after). Firestore rules refuse a change
/// without its entry, and the entry can never be edited or deleted.
class AuditedWriter {
  AuditedWriter(this._db);

  final FirebaseFirestore _db;

  Future<void> write({
    required Granted who,
    required String action,
    required String path,
    required Json after,
    Json? before,
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
    return batch.commit();
  }
}

final auditedWriterProvider = Provider<AuditedWriter>(
  (ref) => AuditedWriter(FirebaseFirestore.instance),
);
