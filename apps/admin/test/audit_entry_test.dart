import 'package:admin/features/audit/domain/audit_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('changes list only what differs between before and after', () {
    const e = AuditEntry(
      id: 'a',
      action: 'saveProduct',
      target: 'products/p1',
      by: 'u',
      before: {
        'basePrice': 13000,
        'name': 'X',
        'defaults': [1],
      },
      after: {
        'basePrice': 14000,
        'name': 'X',
        'defaults': [1, 2],
      },
    );
    expect(e.changes.keys, ['basePrice', 'defaults']);
    expect(e.changes['basePrice'], ('13000', '14000'));
  });

  test('a new document lists every field with no previous value', () {
    const e = AuditEntry(
      id: 'a',
      action: 'replaceAsset',
      target: 'assets/final_p1',
      by: 'u',
      after: {'version': 1},
    );
    expect(e.changes, {'version': (null, '1')});
  });
}
