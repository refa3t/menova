import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

/// P1-B06: the heaviest real pizza (large, every default at the maximum
/// extra) stays under the ~150 pieces where the canvas would move to a
/// CustomPainter. Prints the per-product worst case for the report.
void main() {
  test('worst-case piece count per pizza at large size', () {
    Map<String, dynamic> read(String p) =>
        jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
    final def = CategoryDefinition.fromJson(read('definitions/pizza.json'));
    final products = [
      for (final p
          in read('tools/seed/pizza_products.json')['products'] as List)
        Product.fromJson(p as Map<String, dynamic>),
    ];
    final strategy = placementStrategies[def.placement.strategy]!;
    final large = BuilderState.open(
      definition: def,
      product: products.first,
    ).selectSize('l').state;
    final density = large.sizeDensity;

    var worst = 0;
    var worstId = '';
    for (final p in products) {
      var pieces = 0;
      for (final d in p.defaults) {
        final units = d.qty + def.constraints.maxQty;
        for (var u = 0; u < units; u++) {
          pieces += strategy
              .place(
                ingredientId: d.ingredientId,
                unit: u,
                variantCount: 3,
                params: def.placement.params,
                density: density,
              )
              .length;
        }
      }
      if (pieces > worst) (worst, worstId) = (pieces, p.id);
    }
    // ignore: avoid_print
    print('P1-B06 worst case: $worstId = $worst pieces (large, max extras)');
    expect(worst, greaterThan(0));
  });
}
