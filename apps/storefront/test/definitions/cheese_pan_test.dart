import 'dart:convert';
import 'dart:io';

import 'package:animation/animation.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pricing/pricing.dart';
import 'package:product_builder/product_builder.dart';

/// The cheese pan runs through the same builder state, validators and
/// pricing engine as the pizza and the crepe, from its definition and data
/// only (template for a new category, steps 4 and 5).
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final def = CategoryDefinition.fromJson(read('definitions/cheese_pan.json'));
  final products = {
    for (final p
        in read('tools/seed/cheese_pan_products.json')['products'] as List)
      p['id'] as String: Product.fromJson(p as Map<String, dynamic>),
  };
  // Shared ingredients come from the pizza records, new ones from the pan.
  final ingredients = {
    for (final f in ['pizza', 'cheese_pan'])
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

  BuilderState open(String id) =>
      BuilderState.open(definition: def, product: products['cheese_pan_$id']!);

  test('the definition is valid against the files it will upload', () {
    // Before upload_assets.dart writes the manifest, the pan's assets are
    // the files under assets_src/cheese_pan (definitions_test checks the
    // uploaded ones); the oven images are already uploaded.
    final assetIds = {
      for (final f in Directory(
        '../../assets_src/cheese_pan',
      ).listSync(recursive: true).whereType<File>())
        if (f.path.endsWith('.webp')) f.uri.pathSegments.last.split('.').first,
      for (final f in read(
        'assets_src/animation/cloudinary_manifest.json',
      ).keys)
        f.split('.').first.replaceFirst(RegExp(r'_\d+$'), ''),
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
    for (final p in products.values) {
      expect(
        validateProduct(p, def, ingredientIds: ingredients.keys.toSet()),
        isEmpty,
        reason: p.id,
      );
    }
    for (final id in ['hot_dog', 'smoked_turkey']) {
      expect(validateIngredient(ingredients[id]!), isEmpty, reason: id);
    }
  });

  test('the pan bakes in SlideIntoOven, then Swap and FlyToCart', () {
    expect(def.animation.map((s) => s.step), [
      'SlideIntoOven',
      'Swap',
      'FlyToCart',
    ]);
    final reduced = planSequence(
      sequence: StepSequence(def.animation),
      registry: animSteps,
      total: const Duration(seconds: 3),
      reduceMotion: true,
    );
    expect(reduced.steps.map((s) => s.key), ['Swap', 'FlyToCart']);
  });

  test('the toppings stay inside the pan', () {
    expect(def.base.surface, inInclusiveRange(0.6, 0.8));
    final params = def.placement.params;
    expect(params['radius']! + params['pieceSize']!, lessThanOrEqualTo(1));
  });

  test('a pan opens single, with its defaults, at its base price', () {
    final s = open('mixed_cheese');
    expect(s.selection.sizeId, 'single');
    expect(s.selection.ingredients, {
      'mozzarella': 1,
      'cheddar': 1,
      'roumi': 1,
      'feta': 1,
    });
    expect(price(s), 11000);
  });

  test('the sharing size adds its price, extras cost the same', () {
    var s = open('basterma');
    expect(price(s), 14500);
    s = s.add('basterma').state; // basterma extra is 45 everywhere
    expect(price(s), 19000);
    s = s.selectSize('sharing').state;
    expect(price(s), 24000 + 4500);
  });

  test('removing gives no refund and the max rule applies', () {
    var s = open('hot_dog');
    s = s.remove('cheddar').state;
    expect(price(s), 12000);
    s = s.add('hot_dog').state; // new ingredient, 30
    s = s.add('hot_dog').state;
    expect(price(s), 12000 + 2 * 3000);
    expect(s.add('hot_dog').rejection, BuilderRejection.maxQty);
  });

  test('sauces are offered to every pan at the pizza price', () {
    var s = open('chicken');
    s = s.add('cheddar_sauce').state;
    expect(price(s), 13500 + 1500);
    expect(
      def.addOnGroupsFor(s.product.groupId).single.ingredientIds,
      contains('cheddar_sauce'),
    );
  });
}
