import 'dart:math';

import 'package:core/core.dart';
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

  group('band (P2-04)', () {
    const b = BandPlacement();
    const params = {'piecesPerUnit': 10, 'radius': 0.8, 'bandWidth': 0.3};
    List<PiecePlacement> band(String id, int unit) =>
        b.place(ingredientId: id, unit: unit, variantCount: 3, params: params);

    test('pieces sit in the central strip, inside the radius', () {
      final pieces = band('chicken', 0);
      expect(pieces, hasLength(10));
      for (final p in pieces) {
        expect(p.dy.abs(), lessThanOrEqualTo(0.3 + 1e-9));
        expect(p.dx * p.dx + p.dy * p.dy, lessThanOrEqualTo(0.64 + 1e-9));
      }
    });

    test('stable per unit, and extras use another seed', () {
      expect(band('chicken', 0).first.dx, band('chicken', 0).first.dx);
      expect(band('chicken', 1).first.dx, isNot(band('chicken', 0).first.dx));
    });
  });

  group('drizzle (P2-04)', () {
    const d = DrizzlePlacement();
    const params = {'piecesPerUnit': 12, 'radius': 0.78, 'lines': 3};
    List<PiecePlacement> drizzle(String id, int unit) =>
        d.place(ingredientId: id, unit: unit, variantCount: 3, params: params);

    test('pieces follow lines across the disc, turned along them', () {
      final pieces = drizzle('nutella', 0);
      expect(pieces, hasLength(12));
      for (final p in pieces) {
        expect(
          p.dx * p.dx + p.dy * p.dy,
          lessThanOrEqualTo(0.78 * 0.78 + 1e-6),
        );
        expect(p.rotation.abs(), lessThan(pi / 2)); // along a near-flat line
      }
      // Three lines: pieces cluster around three distinct heights.
      final rows = pieces.map((p) => (p.dy * 4).round()).toSet();
      expect(rows.length, greaterThanOrEqualTo(3));
    });

    test('every unit and ingredient stays inside the radius', () {
      for (final id in ['nutella', 'white_chocolate', 'caramel', 'x', 'y']) {
        for (var unit = 0; unit < 3; unit++) {
          for (final p in drizzle(id, unit)) {
            expect(
              p.dx * p.dx + p.dy * p.dy,
              lessThanOrEqualTo(0.78 * 0.78 + 1e-6),
              reason: '$id unit $unit',
            );
          }
        }
      }
    });

    test('an extra unit draws its lines between the previous ones', () {
      final a = drizzle('nutella', 0).map((p) => p.dy).toList();
      final b = drizzle('nutella', 1).map((p) => p.dy).toList();
      expect(b.first, isNot(a.first));
    });
  });

  test('a definition can give single ingredients their own strategy', () {
    const spec = PlacementSpec(
      strategy: 'band',
      byIngredient: {'nutella': 'drizzle', 'x': 'unknown'},
    );
    expect(spec.strategyFor('nutella'), 'drizzle');
    expect(spec.strategyFor('banana'), 'band');
    final map = strategiesByIngredient(spec);
    expect(map['nutella'], isA<DrizzlePlacement>());
    expect(map.containsKey('x'), isFalse);
  });
}
