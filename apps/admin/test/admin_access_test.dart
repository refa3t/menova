import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the owner and menu managers get in', () {
    expect(adminAccessFor(uid: null), isA<SignedOut>());
    expect(adminAccessFor(uid: 'u', roleClaim: 'reception'), isA<Denied>());
    expect(adminAccessFor(uid: 'u'), isA<Denied>());
    final owner = adminAccessFor(uid: 'u', roleClaim: 'owner') as Granted;
    expect(owner.role, AdminRole.owner);
    expect(
      (adminAccessFor(uid: 'u', roleClaim: 'menu_manager') as Granted).role,
      AdminRole.menuManager,
    );
  });

  test('a menu manager manages the menu, not settings, reports or audit', () {
    for (final a in AdminArea.values) {
      expect(canManage(AdminRole.owner, a), isTrue, reason: '$a');
    }
    expect(canManage(AdminRole.menuManager, AdminArea.products), isTrue);
    expect(canManage(AdminRole.menuManager, AdminArea.assets), isTrue);
    expect(canManage(AdminRole.menuManager, AdminArea.settings), isFalse);
    expect(canManage(AdminRole.menuManager, AdminArea.reports), isFalse);
    expect(canManage(AdminRole.menuManager, AdminArea.audit), isFalse);
  });
}
