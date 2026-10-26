import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricing/pricing.dart';
import 'package:product_builder/product_builder.dart';

/// Stuffed crust (owner request): offered on every pizza, swaps the base
/// for the thick-rim one and adds its price. Driven by data only.
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final def = CategoryDefinition.fromJson(read('definitions/pizza.json'));
  final products = [
    for (final p in read('tools/seed/pizza_products.json')['products'] as List)
      Product.fromJson(p as Map<String, dynamic>),
  ];
  final ingredients = {
    for (final i in read('tools/seed/pizza_ingredients.json')['ingredients']
        as List)
      i['id'] as String: Ingredient.fromJson(i as Map<String, dynamic>),
  };

  test('every pizza offers stuffed crust with a price', () {
    final crust = def.optionGroups.singleWhere((g) => g.id == 'crust');
    expect(crust.choices.map((c) => c.id), contains('stuffed_crust'));
    for (final p in products) {
      expect(p.optionDeltas['stuffed_crust'], greaterThan(0), reason: p.id);
    }
  });

  test('choosing stuffed crust swaps the base and adds its price', () {
    final product = products.first;
    final plain = BuilderState.open(definition: def, product: product);
    final stuffed = plain.selectOption('crust', 'stuffed_crust').state!;
    expect(plain.activeBase.rawAssetId, 'base_pizza_regular_raw');
    expect(stuffed.activeBase.rawAssetId, 'base_pizza_stuffed_raw');

    int total(BuilderState s) => priceItem(
      definition: def,
      product: product,
      ingredients: ingredients,
      selection: s.selection,
      itemQty: 1,
    ).total;
    expect(
      total(stuffed) - total(plain),
      product.optionDeltas['stuffed_crust'],
    );
  });
}
