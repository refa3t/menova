import 'package:flutter_test/flutter_test.dart';
import 'package:reception/features/auth/domain/staff_access.dart';

void main() {
  test('only reception and kitchen roles get in', () {
    expect(staffAccessFor(signedIn: false), StaffAccess.signedOut);
    expect(staffAccessFor(signedIn: true), StaffAccess.denied);
    expect(staffAccessFor(signedIn: true, role: 'admin'), StaffAccess.denied);
    expect(
      staffAccessFor(signedIn: true, role: 'reception'),
      StaffAccess.granted,
    );
    expect(
      staffAccessFor(signedIn: true, role: 'kitchen'),
      StaffAccess.granted,
    );
  });
}
