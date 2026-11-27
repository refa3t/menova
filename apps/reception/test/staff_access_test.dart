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

  group('staff record (P3-01)', () {
    test('a verified record grants reception or kitchen', () {
      for (final r in ['reception', 'kitchen']) {
        expect(
          staffAccessFor(signedIn: true, emailVerified: true, staffRole: r),
          StaffAccess.granted,
          reason: r,
        );
      }
    });

    test('an unverified record asks for verification', () {
      expect(
        staffAccessFor(signedIn: true, staffRole: 'reception'),
        StaffAccess.needsVerification,
      );
    });

    test('a record never grants owner, menu_manager or unknown roles', () {
      for (final r in ['owner', 'menu_manager', 'x']) {
        expect(
          staffAccessFor(signedIn: true, emailVerified: true, staffRole: r),
          StaffAccess.denied,
          reason: r,
        );
        expect(
          staffAccessFor(signedIn: true, staffRole: r),
          StaffAccess.denied,
          reason: 'unverified $r',
        );
      }
    });

    test('the claim wins; signed out stays signed out', () {
      expect(
        staffAccessFor(signedIn: true, role: 'owner', staffRole: 'kitchen'),
        StaffAccess.granted,
      );
      expect(
        staffAccessFor(
          signedIn: false,
          emailVerified: true,
          staffRole: 'reception',
        ),
        StaffAccess.signedOut,
      );
    });

    test('records are keyed by the lower-cased, trimmed email', () {
      expect(staffRecordId(' Rec@X.com '), 'rec@x.com');
    });
  });
}
