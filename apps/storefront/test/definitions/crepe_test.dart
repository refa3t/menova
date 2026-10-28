import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricing/pricing.dart';
import 'package:product_builder/product_builder.dart';

/// P2-03 "no duplicated code": the crepe runs through the same builder
/// state and pricing engine as the pizza, from its definition and data only.
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final def = CategoryDefinition.fromJson(read('definitions/crepe.json'));
  final products = {
    for (final p in read('tools/seed/crepe_products.json')['products'] as List)
      p['id'] as String: Product.fromJson(p as Map<String, dynamic>),
  };
  // Shared ingredients come from the pizza records, new ones from the crepe.
  final ingredients = {
    for (final f in ['pizza', 'crepe'])
      for (final i
          in read('tools/seed/${f}_ingredients.json')['ingredients'] as List)
        i['id'] as String: Ingredient.fromJson(i as Map<String, dynamic>),
  };

  int price(BuilderState s) => priceItem(
    definition: def,
    product: s.product,
    ingredients: ingredients,
    selection: s.selection,
    itemQty: 1,
  ).total;

  test('a crepe opens with its defaults at its base price', () {
    final s = BuilderState.open(
      definition: def,
      product: products['crepe_nutella_banana']!,
    );
    expect(s.selection.sizeId, isNull, reason: 'one size: no size chosen');
    expect(s.selection.ingredients, {'nutella': 1, 'banana': 1});
    expect(price(s), 9500);
  });

  test('extras, removals and the max rule work the same as the pizza', () {
    var s = BuilderState.open(
      definition: def,
      product: products['crepe_nutella_banana']!,
    );
    s = s.add('banana').state; // + banana 10
    expect(price(s), 10500);
    s = s.remove('nutella').state; // without Nutella, no refund
    expect(price(s), 10500);
    s = s.add('banana').state; // default 1 + 2 extras is the maximum
    expect(s.add('banana').rejection, BuilderRejection.maxQty);
  });

  test('a savoury crepe reuses the pizza ingredient prices', () {
    var s = BuilderState.open(
      definition: def,
      product: products['crepe_chicken']!,
    );
    s = s.add('chicken').state; // chicken extra is 35 everywhere
    expect(price(s), 11500 + 3500);
  });
}
