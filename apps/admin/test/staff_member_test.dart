import 'package:admin/features/staff/domain/staff_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the owner can never be granted from the panel', () {
    expect(grantableStaffRoles, ['reception', 'kitchen', 'menu_manager']);
    expect(grantableStaffRoles, isNot(contains('owner')));
  });

  test('records are keyed by the lower-cased, trimmed email', () {
    expect(staffRecordId('  Ali@Example.COM '), 'ali@example.com');
  });

  test('only email-shaped ids are accepted', () {
    expect(isValidStaffEmail('ali@example.com'), isTrue);
    expect(isValidStaffEmail(' Ali@Example.com '), isTrue);
    for (final bad in [
      '',
      'ali',
      'ali@',
      '@x.com',
      'a@b',
      'a b@x.com',
      'a/b@x.com',
    ]) {
      expect(isValidStaffEmail(bad), isFalse, reason: bad);
    }
  });

  test('a removal is audited under an id fixed by the record version', () {
    const m = StaffMember(email: 'a@x.com', role: 'kitchen', lastAuditId: 'A1');
    expect(m.removalAuditId, 'remove_A1');
  });
}
