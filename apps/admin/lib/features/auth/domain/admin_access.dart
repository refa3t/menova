/// Admin roles (custom claim `role`, set with tools/bin/set_staff_role.dart;
/// Firestore rules check the same claim) and what each may manage (P3-01).
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
}

/// Sections of the admin panel.
enum AdminArea {
  products,
  ingredients,
  assets,
  categories,
  catalogCheck,
  settings,
  reports,
  audit,
}

/// The owner manages everything; a menu manager manages the menu content
/// only (never the store settings, sales reports or the audit log).
bool canManage(AdminRole role, AdminArea area) => switch (role) {
  AdminRole.owner => true,
  AdminRole.menuManager => switch (area) {
    AdminArea.products ||
    AdminArea.ingredients ||
    AdminArea.assets ||
    AdminArea.categories ||
    AdminArea.catalogCheck => true,
    AdminArea.settings || AdminArea.reports || AdminArea.audit => false,
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

class Granted extends AdminAccess {
  const Granted({required this.role, required this.uid, this.email});
  final AdminRole role;
  final String uid;
  final String? email;
}

AdminAccess adminAccessFor({
  required String? uid,
  String? email,
  Object? roleClaim,
}) {
  if (uid == null) return const SignedOut();
  final role = AdminRole.fromClaim(roleClaim);
  return role == null
      ? const Denied()
      : Granted(role: role, uid: uid, email: email);
}
