import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('definitions/pizza.json and seed products parse', () {
    final def = CategoryDefinition.fromJson(
      jsonDecode(File('../../definitions/pizza.json').readAsStringSync()),
    );
    final seed =
        jsonDecode(
              File('../../tools/seed/pizza_products.json').readAsStringSync(),
            )
            as Map;
    final products = (seed['products'] as List)
        .map((p) => Product.fromJson(p))
        .toList();
    for (final p in products) {
      for (final d in p.defaults) {
        expect(def.allowedIngredientIds, contains(d.ingredientId));
      }
    }
    expect(products, hasLength(27));
  });
}
