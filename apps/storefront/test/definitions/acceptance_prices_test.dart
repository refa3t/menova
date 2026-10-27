import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricing/pricing.dart';

/// P0-11 price cases (docs/ACCEPTANCE_PIZZA.md, section B) run against the
/// real definition and seed data, so the acceptance document stays true.
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final def = CategoryDefinition.fromJson(read('definitions/pizza.json'));
  final products = {
    for (final p in read('tools/seed/pizza_products.json')['products'] as List)
      p['id'] as String: Product.fromJson(p as Map<String, dynamic>),
  };
  final ingredients = {
    for (final i
        in read('tools/seed/pizza_ingredients.json')['ingredients'] as List)
      i['id'] as String: Ingredient.fromJson(i as Map<String, dynamic>),
  };

  int price(
    String productId, {
    String size = 's',
    Map<String, int> change = const {},
    Map<String, String> options = const {},
    int qty = 1,
  }) {
    final product = products[productId]!;
    return priceItem(
      definition: def,
      product: product,
      ingredients: ingredients,
      selection: Selection(
        productId: product.id,
        categoryId: product.categoryId,
        definitionVersion: def.definitionVersion,
        sizeId: size,
        options: {'crust': 'classic_crust', ...options},
        ingredients: {
          for (final d in product.defaults) d.ingredientId: d.qty,
          ...change,
        },
      ),
      itemQty: qty,
    ).total;
  }

  test('B1 unmodified small margherita is its base price', () {
    expect(price('pizza_margherita'), 13000);
  });
  test('B2 medium margherita with one extra mozzarella', () {
    expect(
      price('pizza_margherita', size: 'm', change: {'mozzarella': 2}),
      21000,
    );
  });
  test('B3 removing basil does not lower the price', () {
    expect(price('pizza_margherita', change: {'basil': 0}), 13000);
  });
  test('B4 two extras allowed above the default, a third is refused', () {
    expect(price('pizza_margherita', change: {'mozzarella': 3}), 19000);
    expect(
      () => price('pizza_margherita', change: {'mozzarella': 4}),
      throwsA(isA<PricingException>().having((e) => e.code, 'code', 'maxQty')),
    );
  });
  test('B5 large margherita with stuffed crust', () {
    expect(
      price('pizza_margherita', size: 'l', options: {'crust': 'stuffed_crust'}),
      27500,
    );
  });
  test('B7 medium pepperoni with two extra pepperoni', () {
    expect(
      price('pizza_pepperoni', size: 'm', change: {'pepperoni': 3}),
      28500,
    );
  });
  test('B8 large seafood, extra shrimp and stuffed crust', () {
    expect(
      price(
        'pizza_seafood',
        size: 'l',
        change: {'shrimp': 2},
        options: {'crust': 'stuffed_crust'},
      ),
      45500,
    );
  });
  test('B9 quantity multiplies the item total', () {
    expect(
      price('pizza_margherita', size: 'm', change: {'mozzarella': 2}, qty: 2),
      42000,
    );
  });
  test('B10 an ingredient outside the category is refused', () {
    expect(
      () => price('pizza_margherita', change: {'not_an_ingredient': 1}),
      throwsA(
        isA<PricingException>().having((e) => e.code, 'code', 'notAllowed'),
      ),
    );
  });
}
