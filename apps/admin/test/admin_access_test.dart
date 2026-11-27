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
    expect(canManage(AdminRole.menuManager, AdminArea.catalogCheck), isTrue);
    expect(canManage(AdminRole.menuManager, AdminArea.offers), isTrue);
    expect(canManage(AdminRole.menuManager, AdminArea.drafts), isTrue);
    expect(canManage(AdminRole.menuManager, AdminArea.settings), isFalse);
    expect(canManage(AdminRole.menuManager, AdminArea.reports), isFalse);
    expect(canManage(AdminRole.menuManager, AdminArea.audit), isFalse);
    expect(canManage(AdminRole.menuManager, AdminArea.staff), isFalse);
  });

  group('staff record (P3-01)', () {
    test('a verified record grants menu_manager', () {
      final a = adminAccessFor(
        uid: 'u',
        email: 'm@x.com',
        emailVerified: true,
        staffRole: 'menu_manager',
      );
      expect((a as Granted).role, AdminRole.menuManager);
      expect(a.email, 'm@x.com');
    });

    test('an unverified record asks for verification, grants nothing', () {
      final a = adminAccessFor(
        uid: 'u',
        email: 'm@x.com',
        staffRole: 'menu_manager',
      );
      expect(a, isA<NeedsVerification>());
      expect((a as NeedsVerification).email, 'm@x.com');
    });

    test('a record never grants owner, nor a non-admin role', () {
      for (final role in ['owner', 'reception', 'kitchen', 'x', null]) {
        expect(
          adminAccessFor(uid: 'u', emailVerified: true, staffRole: role),
          isA<Denied>(),
          reason: '$role',
        );
        expect(
          adminAccessFor(uid: 'u', staffRole: role),
          isA<Denied>(),
          reason: 'unverified $role',
        );
      }
    });

    test('the claim wins, verified or not', () {
      final a = adminAccessFor(
        uid: 'u',
        roleClaim: 'owner',
        staffRole: 'menu_manager',
      );
      expect((a as Granted).role, AdminRole.owner);
      expect(
        (adminAccessFor(uid: 'u', roleClaim: 'menu_manager') as Granted).role,
        AdminRole.menuManager,
      );
    });

    test('signed out stays signed out', () {
      expect(
        adminAccessFor(
          uid: null,
          emailVerified: true,
          staffRole: 'menu_manager',
        ),
        isA<SignedOut>(),
      );
    });
  });
}
