/// Staff roles allowed into the reception dashboard (custom claim `role`,
/// set server-side; Firestore rules check the same claim).
const staffRoles = {'reception', 'kitchen'};

enum StaffAccess { signedOut, denied, granted }

StaffAccess staffAccessFor({required bool signedIn, Object? role}) {
  if (!signedIn) return StaffAccess.signedOut;
  return staffRoles.contains(role) ? StaffAccess.granted : StaffAccess.denied;
}
