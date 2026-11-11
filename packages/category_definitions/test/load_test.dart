import 'package:category_definitions/category_definitions.dart';
import 'package:test/test.dart';

void main() {
  test('bundled pizza definition loads', () {
    final r = loadBundledDefinitions();
    expect(r.rejected, isEmpty);
    // 38 toppings and 9 sauces.
    expect(r.definitions['pizza']!.allowedIngredientIds, hasLength(47));
    expect(
      r.definitions['pizza']!.addOnGroups.single.ingredientIds,
      hasLength(9),
    );
  });
}
