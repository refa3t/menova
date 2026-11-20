import 'dart:convert';
import 'dart:io';

import 'package:animation/animation.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricing/pricing.dart';
import 'package:product_builder/product_builder.dart';

/// The tortilla wrap runs through the same builder state and pricing engine
/// as the pizza and the crepe, from its definition and data only, and its
/// definition is valid against the engines and its own asset files (before
/// they are uploaded; `definitions_test` checks the uploaded ones).
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final def = CategoryDefinition.fromJson(read('definitions/tortilla.json'));
  final products = {
    for (final p
        in read('tools/seed/tortilla_products.json')['products'] as List)
      p['id'] as String: Product.fromJson(p as Map<String, dynamic>),
  };
  // Shared ingredients come from the pizza and crepe records.
  final ingredients = {
    for (final f in ['pizza', 'crepe', 'tortilla'])
      for (final i
          in read('tools/seed/${f}_ingredients.json')['ingredients'] as List)
        i['id'] as String: Ingredient.fromJson(i as Map<String, dynamic>),
  };

  int price(BuilderState s, {int qty = 1}) => priceItem(
    definition: def,
    product: s.product,
    ingredients: ingredients,
    selection: s.selection,
    itemQty: qty,
  ).total;

  BuilderState open(String id) =>
      BuilderState.open(definition: def, product: products[id]!);

  test('the definition is valid against the engines and its asset files', () {
    final assetIds = <String>{
      for (final dir in ['animation', 'tortilla', 'pizza', 'crepe'])
        for (final f in Directory(
          '../../assets_src/$dir',
        ).listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.webp'))
            f.uri.pathSegments.last
                .split('.')
                .first
                .replaceFirst(RegExp(r'_\d+$'), ''),
    };
    final issues = validateDefinition(
      def,
      placementStrategies: placementStrategies.keys.toSet(),
      animationSteps: animationStepKeys,
      enterProfiles: enterProfiles.keys.toSet(),
      exitProfiles: exitProfiles.keys.toSet(),
      assetIds: assetIds,
      ingredientIds: ingredients.keys.toSet(),
    );
    expect(issues, isEmpty);
    // Every product's defaults are allowed, and its group is defined.
    for (final p in products.values) {
      expect(p.categoryId, def.id);
      for (final d in p.defaults) {
        expect(def.allowedIngredientIds, contains(d.ingredientId));
      }
      expect(def.productGroups.map((g) => g.id), contains(p.groupId));
    }
  });

  test('a wrap rolls up after its sides fold in, then is served', () {
    expect(def.animation.map((s) => s.step), [
      'Griddle',
      'Fold',
      'Fold',
      'Roll',
      'Swap',
      'Shrink',
      'FlyToCart',
    ]);
    // Reduced motion keeps Swap and FlyToCart, both showing the rolled log.
    for (final s in def.animation.where(
      (s) => s.step == 'Swap' || s.step == 'FlyToCart',
    )) {
      expect(RollShape.from(s.params['roll']), isNotNull, reason: s.step);
    }
  });

  test('a chicken shawarma wrap opens with its defaults at its price', () {
    final s = open('tortilla_chicken_shawarma');
    expect(s.selection.sizeId, isNull, reason: 'one size: no size chosen');
    expect(s.selection.ingredients, {
      'chicken_shawarma': 1,
      'fries': 1,
      'pickles': 1,
      'garlic_sauce': 1,
    });
    expect(price(s), 10500);
  });

  test('extras, removals and the max rule work as everywhere else', () {
    var s = open('tortilla_chicken_shawarma');
    s = s.add('fries').state; // + fries 15
    s = s.add('cheddar').state; // + cheddar 25 (an extra, not a default)
    expect(price(s), 10500 + 1500 + 2500);
    s = s.remove('pickles').state; // without pickles, no refund
    expect(price(s), 10500 + 1500 + 2500);
    s = s.add('fries').state; // default 1 + 2 extras is the maximum
    expect(s.add('fries').rejection, BuilderRejection.maxQty);
    expect(price(s, qty: 2), 2 * (10500 + 2 * 1500 + 2500));
  });

  test('shared ingredients keep their one price', () {
    var s = open('tortilla_fajita');
    expect(price(s), 12500);
    s = s.add('chicken').state; // chicken extra is 35 everywhere
    s = s.add('ranch_sauce').state; // ranch 15, as on the pizza
    expect(price(s), 12500 + 3500 + 1500);
  });

  test('a sweet wrap takes the sweet sauces', () {
    var s = open('tortilla_nutella_banana');
    expect(price(s), 9000);
    s = s.add('strawberry_sauce').state; // + 15
    s = s.add('banana').state; // + 10
    expect(price(s), 9000 + 1500 + 1000);
  });

  test('an ingredient outside the category is refused', () {
    final s = open('tortilla_tuna');
    expect(s.add('shrimp').rejection, isNotNull);
  });
}
