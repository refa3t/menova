/// Admin roles and what each may manage (P3-01). A role comes from the custom
/// claim `role` (tools/bin/set_staff_role.dart) or from the owner's staff
/// record staff/{lowercased email} once the email is verified; Firestore
/// rules check the same (hasRole). The owner is a claim only.
enum AdminRole {
  owner('owner'),
  menuManager('menu_manager');

  const AdminRole(this.claim);
  final String claim;

  static AdminRole? fromClaim(Object? claim) {
    for (final r in values) {
      if (r.claim == claim) return r;
    }
    return null;
  }

  /// The admin role a staff record may grant: never the owner.
  static AdminRole? fromStaffRecord(Object? role) {
    final r = fromClaim(role);
    return r == owner ? null : r;
  }
}

/// Sections of the admin panel.
enum AdminArea {
  products,
  ingredients,
  drafts,
  assets,
  categories,
  offers,
  catalogCheck,
  settings,
  reports,
  audit,
  staff,
}

/// The owner manages everything; a menu manager manages the menu content
/// only (never the store settings, sales reports or the audit log).
bool canManage(AdminRole role, AdminArea area) => switch (role) {
  AdminRole.owner => true,
  AdminRole.menuManager => switch (area) {
    AdminArea.products ||
    AdminArea.ingredients ||
    AdminArea.drafts ||
    AdminArea.assets ||
    AdminArea.categories ||
    AdminArea.offers ||
    AdminArea.catalogCheck => true,
    AdminArea.settings ||
    AdminArea.reports ||
    AdminArea.audit ||
    AdminArea.staff => false,
  },
};

sealed class AdminAccess {
  const AdminAccess();
}

class SignedOut extends AdminAccess {
  const SignedOut();
}

class Denied extends AdminAccess {
  const Denied();
}

/// Signed in with an email that has an admin staff record, not verified yet:
/// the record counts only after verification (rules check the same).
class NeedsVerification extends AdminAccess {
  const NeedsVerification({this.email});
  final String? email;
}

class Granted extends AdminAccess {
  const Granted({required this.role, required this.uid, this.email});
  final AdminRole role;
  final String uid;
  final String? email;
}

/// Access from the claim first, else from the staff record's role
/// ([staffRole], null when there is no record) with a verified email.
AdminAccess adminAccessFor({
  required String? uid,
  String? email,
  Object? roleClaim,
  bool emailVerified = false,
  Object? staffRole,
}) {
  if (uid == null) return const SignedOut();
  final claimed = AdminRole.fromClaim(roleClaim);
  if (claimed != null) return Granted(role: claimed, uid: uid, email: email);
  final recorded = AdminRole.fromStaffRecord(staffRole);
  if (recorded == null) return const Denied();
  return emailVerified
      ? Granted(role: recorded, uid: uid, email: email)
      : NeedsVerification(email: email);
}
