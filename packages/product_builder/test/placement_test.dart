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

  test('band and drizzle can be centred elsewhere (half-moon base)', () {
    const params = {
      'piecesPerUnit': 10,
      'radius': 0.4,
      'bandWidth': 0.1,
      'offsetY': 0.2,
      'lines': 2,
    };
    for (final s in const [BandPlacement(), DrizzlePlacement()]) {
      for (final p in s.place(
        ingredientId: 'x',
        unit: 0,
        variantCount: 1,
        params: params,
      )) {
        expect(p.dy, greaterThan(0.2 - 0.4 - 1e-6));
        expect(p.dy, lessThan(0.2 + 0.4 + 1e-6));
      }
    }
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

  group('sauce (owner request: liquid, evenly spread)', () {
    const sauce = SaucePlacement();
    const disc = {'lines': 6, 'radius': 0.7, 'angle': 30, 'wave': 0.02};
    // The crepe: a strip across a half moon.
    const strip = {
      'lines': 7,
      'radius': 0.42,
      'bandWidth': 0.13,
      'offsetY': 0.16,
      'angle': 80,
      'wave': 0.01,
    };
    List<({double x, double y})> pour(
      Map<String, num> params, {
      int unit = 0,
      double density = 1,
      String id = 'ketchup',
    }) {
      final lines = sauce.lines(
        ingredientId: id,
        unit: unit,
        params: params,
        density: density,
      );
      expect(lines, hasLength(1), reason: 'one continuous stroke');
      return lines.single;
    }

    // Offset of a point across the passes (angle 30 degrees).
    double across(({double x, double y}) p) =>
        -p.x * sin(pi / 6) + p.y * cos(pi / 6);

    test('places no pieces: the canvas draws it as a liquid', () {
      expect(
        sauce.place(
          ingredientId: 'ketchup',
          unit: 0,
          variantCount: 1,
          params: disc,
        ),
        isEmpty,
      );
      expect(placementStrategies['sauce'], isA<LinePlacement>());
    });

    test('one zigzag of evenly spaced passes over the whole disc', () {
      final stroke = pour(disc);
      expect(stroke, equals(pour(disc)), reason: 'deterministic');
      for (final p in stroke) {
        // The rounded turns stay (nearly) on the surface too.
        expect(sqrt(p.x * p.x + p.y * p.y), lessThan(0.7 + 0.05));
      }
      // Six passes, each at its own offset, one spacing (1.4 / 6) apart.
      final rows = <int>{for (final p in stroke) (across(p) / 0.02).round()};
      final centres = [for (var l = 0; l < 6; l++) -0.7 + 1.4 / 6 * (l + 0.5)];
      for (final c in centres) {
        expect(
          rows.any((r) => (r * 0.02 - c).abs() < 0.03),
          isTrue,
          reason: 'a pass near $c',
        );
      }
      // Back and forth: the stroke crosses the disc six times.
      final along = [
        for (final p in stroke) p.x * cos(pi / 6) + p.y * sin(pi / 6),
      ];
      var turns = 0;
      for (var i = 2; i < along.length; i++) {
        final a = along[i - 1] - along[i - 2], b = along[i] - along[i - 1];
        if (a * b < 0) turns++;
      }
      expect(turns, inInclusiveRange(5, 10));
    });

    test('an extra unit pours between the earlier passes', () {
      double nearest(List<double> xs, double v) =>
          xs.map((x) => (x - v).abs()).reduce(min);
      // Mid-pass points only (the turns are near the edge).
      List<double> middles(List<({double x, double y})> stroke) => [
        for (final p in stroke)
          if ((p.x * cos(pi / 6) + p.y * sin(pi / 6)).abs() < 0.15) across(p),
      ];
      final first = middles(pour(disc));
      final second = middles(pour(disc, unit: 1));
      const spacing = 1.4 / 6;
      // The second unit's passes sit half a spacing from the first's.
      expect(second, isNotEmpty);
      for (final v in second) {
        expect(nearest(first, v), greaterThan(spacing * 0.3));
      }
    });

    test('a larger size pours more passes', () {
      double extent(List<({double x, double y})> s) {
        final xs = s.map(across).toList();
        return xs.reduce(max) - xs.reduce(min);
      }

      final small = pour(disc), large = pour(disc, density: 1.49);
      expect(large.length, greaterThan(small.length));
      expect(extent(large), greaterThan(extent(small)));
    });

    test('a strip keeps the sauce on it (the crepe filling)', () {
      final stroke = pour(strip, id: 'nutella');
      expect(stroke.length, greaterThan(20));
      for (final p in stroke) {
        expect(p.y, inInclusiveRange(0.16 - 0.13 - 0.01, 0.16 + 0.13 + 0.01));
        expect(p.x.abs(), lessThan(0.42 + 0.01));
      }
      // Near-vertical passes spread along the whole strip.
      final xs = stroke.map((p) => p.x).toList();
      expect(xs.reduce(max) - xs.reduce(min), greaterThan(0.6));
    });

    test('each sauce has its own angle unless the definition sets one', () {
      final params = {'lines': 4, 'radius': 0.7};
      final a = pour(params, id: 'ketchup'), b = pour(params, id: 'mayonnaise');
      expect(a.first, isNot(b.first));
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
