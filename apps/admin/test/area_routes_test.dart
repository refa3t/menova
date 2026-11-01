import 'package:admin/app/area_routes.dart';
import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every role opens only the sections it manages', () {
    for (final e in areaRoutes.entries) {
      expect(mayOpen(AdminRole.owner, e.value), isTrue, reason: e.value);
    }
    expect(mayOpen(AdminRole.menuManager, '/'), isTrue);
    expect(mayOpen(AdminRole.menuManager, '/products/p1'), isTrue);
    expect(mayOpen(AdminRole.menuManager, '/check'), isTrue);
    // A typed link to an owner section goes nowhere.
    expect(mayOpen(AdminRole.menuManager, '/reports'), isFalse);
    expect(mayOpen(AdminRole.menuManager, '/settings'), isFalse);
    expect(mayOpen(AdminRole.menuManager, '/audit'), isFalse);
  });

  test('every section has its route', () {
    expect(areaRoutes.keys.toSet(), AdminArea.values.toSet());
  });
}
