/// Roles the owner grants from the panel (P3-01). Never the owner: that stays
/// a custom claim (tools/bin/set_staff_role.dart), and Firestore rules refuse
/// it in a staff record.
const grantableStaffRoles = ['reception', 'kitchen', 'menu_manager'];

/// The staff record id for [email]: trimmed and lower-cased, as the rules
/// look it up from the signed-in token's email.
String staffRecordId(String email) => email.trim().toLowerCase();

/// Whether [email] can name a staff record (the rules check the same shape).
bool isValidStaffEmail(String email) =>
    RegExp(r'^[^@/\s]+@[^@/\s]+\.[^@/\s]+$').hasMatch(staffRecordId(email));

/// One staff record: staff/{email} = {role, addedBy, addedByEmail, addedAt,
/// lastAuditId}. addedBy/addedAt name the owner who last set the role.
class StaffMember {
  const StaffMember({
    required this.email,
    required this.role,
    required this.lastAuditId,
    this.addedByEmail,
    this.addedAt,
  });

  final String email;
  final String role;
  final String lastAuditId;
  final String? addedByEmail;
  final DateTime? addedAt;

  /// The audit entry id that records this record's removal: unique per
  /// version of the record, so the rules can require it on delete.
  String get removalAuditId => 'remove_$lastAuditId';
}
