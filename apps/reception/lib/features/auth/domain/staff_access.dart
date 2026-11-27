/// Roles allowed into the reception dashboard. A role comes from the custom
/// claim `role` (tools/bin/set_staff_role.dart) or from the owner's staff
/// record staff/{lowercased email} once the email is verified; Firestore
/// rules check the same (hasRole). The owner sees the orders too, but only
/// by claim: a staff record never grants owner.
const staffRoles = {'reception', 'kitchen', 'owner'};

/// Roles a staff record may grant here.
const recordStaffRoles = {'reception', 'kitchen'};

enum StaffAccess { signedOut, denied, needsVerification, granted }

/// The staff record id for [email], as the rules look it up.
String staffRecordId(String email) => email.trim().toLowerCase();

/// Access from the claim first, else from the staff record's role
/// ([staffRole], null when there is none) with a verified email.
StaffAccess staffAccessFor({
  required bool signedIn,
  Object? role,
  bool emailVerified = false,
  Object? staffRole,
}) {
  if (!signedIn) return StaffAccess.signedOut;
  if (staffRoles.contains(role)) return StaffAccess.granted;
  if (!recordStaffRoles.contains(staffRole)) return StaffAccess.denied;
  return emailVerified ? StaffAccess.granted : StaffAccess.needsVerification;
}
