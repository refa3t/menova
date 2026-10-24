// Runs the golden vectors (test_vectors/pricing.json), the contract shared
// with the TypeScript server engine (P1-D02 / P1-D04).
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:pricing/pricing.dart';
import 'package:test/test.dart';

void main() {
  final v =
      jsonDecode(File('../../test_vectors/pricing.json').readAsStringSync())
          as Map<String, dynamic>;
  final rules = PricingRules(
    version: v['rules']['version'] as int,
    roundingStep: v['rules']['roundingStep'] as int,
  );
  final definition = CategoryDefinition.fromJson(v['definition']);
  final ingredients = {
    for (final e in (v['ingredients'] as Map<String, dynamic>).entries)
      e.key: Ingredient.fromJson(e.value as Map<String, dynamic>),
  };
  final products = {
    for (final e in (v['products'] as Map<String, dynamic>).entries)
      e.key: Product.fromJson(e.value as Map<String, dynamic>),
  };

  test('rules match the engine rules', () {
    expect(rules.version, PricingRules.current.version);
    expect(rules.roundingStep, PricingRules.current.roundingStep);
  });

  for (final c in (v['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'], () {
      final product = products[c['productId']]!;
      final selection = Selection.fromJson({
        'productId': product.id,
        'categoryId': product.categoryId,
        'definitionVersion': definition.definitionVersion,
        ...c['selection'] as Map<String, dynamic>,
      });
      PriceBreakdown run() => priceItem(
        definition: definition,
        product: product,
        ingredients: ingredients,
        selection: selection,
        itemQty: c['itemQty'] as int,
        rules: rules,
      );
      if (c['expectError'] != null) {
        expect(
          run,
          throwsA(
            isA<PricingException>().having(
              (e) => e.code,
              'code',
              c['expectError'],
            ),
          ),
        );
        return;
      }
      final e = c['expect'] as Map<String, dynamic>;
      final r = run();
      expect(r.lines, [
        for (final l in e['lines'] as List) PriceLine.fromJson(l),
      ]);
      expect(r.unitSubtotal, e['unitSubtotal']);
      expect(r.rounding, e['rounding']);
      expect(r.total, e['total']);
      expect(r.ruleVersion, rules.version);
    });
  }
}
