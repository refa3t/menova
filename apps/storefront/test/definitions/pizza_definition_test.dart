import 'dart:convert';
import 'dart:io';

import 'package:animation/animation.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

/// P1-A10 in CI: the real definitions validate against the real engine
/// registries, uploaded assets and seed ingredients.
void main() {
  test('definitions/pizza.json is valid', () {
    Map<String, dynamic> read(String p) =>
        jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
    final def = CategoryDefinition.fromJson(read('definitions/pizza.json'));
    final manifest = read('assets_src/pizza/cloudinary_manifest.json');
    final ingredients = read('tools/seed/pizza_ingredients.json');
    final issues = validateDefinition(
      def,
      placementStrategies: placementStrategies.keys.toSet(),
      animationSteps: animationStepKeys,
      assetIds: {for (final f in manifest.keys) f.split('.').first},
      ingredientIds: {
        for (final i in ingredients['ingredients'] as List) i['id'] as String,
      },
    );
    expect(issues, isEmpty);
    expect(
      loadBundledDefinitions(
        placementStrategies: placementStrategies.keys.toSet(),
        animationSteps: animationStepKeys,
      ).rejected,
      isEmpty,
    );
  });
}
