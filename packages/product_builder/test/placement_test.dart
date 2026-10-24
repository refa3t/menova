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
}
