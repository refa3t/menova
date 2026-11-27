import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/domain/admin_access.dart';
import '../domain/staff_member.dart';

/// Staff records (P3-01), owner only. Like every admin change, each write is
/// one batch with its audit entry (see AuditedWriter); the rules refuse any
/// write without it, and any role other than [grantableStaffRoles].
class StaffRepository {
  StaffRepository(this._db);

  final FirebaseFirestore _db;

  Stream<List<StaffMember>> watch() =>
      _db.collection('staff').snapshots().map((q) {
        final list = [
          for (final d in q.docs)
            StaffMember(
              email: d.id,
              role: '${d.data()['role']}',
              lastAuditId: '${d.data()['lastAuditId']}',
              addedByEmail: d.data()['addedByEmail'] as String?,
              addedAt: (d.data()['addedAt'] as Timestamp?)?.toDate(),
            ),
        ]..sort((a, b) => a.email.compareTo(b.email));
        return list;
      });

  /// Adds [email] with [role], or changes the role of an existing record
  /// ([before] is its current state).
  Future<void> save({
    required Granted who,
    required String email,
    required String role,
    StaffMember? before,
  }) {
    final id = staffRecordId(email);
    final audit = _db.collection('auditLog').doc();
    return (_db.batch()
          ..set(audit, {
            'action': 'saveStaff',
            'target': 'staff/$id',
            'by': who.uid,
            'byEmail': ?who.email,
            'at': FieldValue.serverTimestamp(),
            'before': before == null ? null : {'role': before.role},
            'after': {'role': role},
          })
          ..set(_db.doc('staff/$id'), {
            'role': role,
            'addedBy': who.uid,
            'addedByEmail': ?who.email,
            'addedAt': FieldValue.serverTimestamp(),
            'lastAuditId': audit.id,
          }))
        .commit();
  }

  /// Removes [member]: the audit entry id is fixed by the record's version
  /// ([StaffMember.removalAuditId]), which the rules require on delete.
  Future<void> remove({required Granted who, required StaffMember member}) {
    return (_db.batch()
          ..set(_db.doc('auditLog/${member.removalAuditId}'), {
            'action': 'removeStaff',
            'target': 'staff/${member.email}',
            'by': who.uid,
            'byEmail': ?who.email,
            'at': FieldValue.serverTimestamp(),
            'before': {'role': member.role},
            'after': <String, Object?>{},
          })
          ..delete(_db.doc('staff/${member.email}')))
        .commit();
  }
}

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(FirebaseFirestore.instance),
);

final staffMembersProvider = StreamProvider<List<StaffMember>>(
  (ref) => ref.watch(staffRepositoryProvider).watch(),
);
