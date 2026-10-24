import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

void main() {
  const s = ScatterPlacement();
  const params = {'piecesPerUnit': 9, 'radius': 0.74};

  List<PiecePlacement> place(String id, int unit) =>
      s.place(ingredientId: id, unit: unit, variantCount: 3, params: params);

  test('same ingredient and unit give identical placements', () {
    final a = place('olive', 0), b = place('olive', 0);
    expect(
      a.map((p) => [p.dx, p.dy, p.rotation, p.variant]),
      b.map((p) => [p.dx, p.dy, p.rotation, p.variant]),
    );
  });

  test('extra units use a different seed than the default unit', () {
    expect(place('olive', 1).first.dx, isNot(place('olive', 0).first.dx));
  });

  test('pieces stay inside the radius and count is honoured', () {
    final pieces = place('cheese', 0);
    expect(pieces, hasLength(9));
    for (final p in pieces) {
      expect(p.dx * p.dx + p.dy * p.dy, lessThanOrEqualTo(0.74 * 0.74 + 1e-9));
    }
  });

  test('stableSeed is platform independent', () {
    expect(stableSeed('a'), 0xe40c292c);
  });

  group('rings', () {
    const r = RingsPlacement();
    List<PiecePlacement> ring(String id, int unit, {double density = 1}) =>
        r.place(
          ingredientId: id,
          unit: unit,
          variantCount: 3,
          params: const {'piecesPerUnit': 14, 'radius': 0.74},
          density: density,
        );

    test('count is honoured and scales with density', () {
      expect(ring('olive', 0), hasLength(14));
      expect(ring('olive', 0, density: 1.49), hasLength(21));
    });

    test('pieces are evenly spread on rings inside the radius', () {
      final pieces = ring('olive', 0);
      final radii = pieces
          .map((p) => (sqrt(p.dx * p.dx + p.dy * p.dy) * 1e6).round() / 1e6)
          .toSet();
      expect(radii.length, lessThanOrEqualTo(3), reason: 'few distinct rings');
      for (final rr in radii) {
        expect(rr, lessThanOrEqualTo(0.74 + 1e-9));
      }
    });

    test('deterministic, and extra units do not reuse the same spots', () {
      final a = ring('olive', 0).map((p) => p.dx).toList();
      expect(ring('olive', 0).map((p) => p.dx).toList(), a);
      final b = ring('olive', 1).map((p) => p.dx).toSet();
      expect(b.intersection(a.toSet()), isEmpty);
    });
  });
}
