import 'package:admin/features/drafts/domain/draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final live = {
    'id': 'p1',
    'name': 'TEMP',
    'basePrice': 13000,
    'isAvailable': true,
    'sizeDeltas': {'m': 5000, 'l': 10000},
  };

  test('a draft keeps only the changed fields, with their live values', () {
    final d = diffRecord(live, {
      ...live,
      'basePrice': 14000,
      // Same map, other key order: not a change.
      'sizeDeltas': {'l': 10000, 'm': 5000},
    });
    expect(d.changes, {'basePrice': 14000});
    expect(d.base, {'basePrice': 13000});
    expect(diffRecord(live, {...live}).changes, isEmpty);
    // A new record is all changes.
    expect(diffRecord(null, live), (changes: live, base: null));
  });

  test('publishing applies the draft on top of the live record', () {
    final draft = Draft(
      target: 'products/p1',
      kind: DraftKind.product,
      changes: const {'basePrice': 14000},
      base: const {'basePrice': 13000},
    );
    expect(draft.id, 'products__p1');
    expect(draft.recordId, 'p1');
    // Marked unavailable live meanwhile: kept.
    final now = {...live, 'isAvailable': false};
    final after = draft.applyTo(now);
    expect(after['basePrice'], 14000);
    expect(after['isAvailable'], isFalse);
    expect(draft.conflictsWith(now), isEmpty);
    // The price itself changed live meanwhile: flagged.
    expect(draft.conflictsWith({...live, 'basePrice': 13500}), ['basePrice']);
  });

  test('a draft knows its kind from its target', () {
    expect(DraftKind.ofTarget('products/p1'), DraftKind.product);
    expect(DraftKind.ofTarget('ingredients/cheese'), DraftKind.ingredient);
    expect(DraftKind.ofTarget('offers/o1'), isNull);
  });

  test('JSON equality ignores map key order, not values', () {
    expect(
      jsonEquals(
        {
          'a': 1,
          'b': [1, 2],
        },
        {
          'b': [1, 2],
          'a': 1,
        },
      ),
      isTrue,
    );
    expect(jsonEquals({'a': 1}, {'a': 2}), isFalse);
    expect(jsonEquals([1, 2], [2, 1]), isFalse);
    expect(jsonEquals(null, null), isTrue);
  });
}
