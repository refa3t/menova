import 'package:core/core.dart';
import 'package:pricing/pricing.dart';
import 'package:test/test.dart';

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'c',
  definitionVersion: 1,
  name: 'c',
  base: BaseSpec(shape: 'circle', rawAssetId: 'b'),
  allowedIngredientIds: ['x'],
  placement: PlacementSpec(strategy: 'scatter'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [],
  optionGroups: [],
  animation: [StepSpec(step: 'Oven')],
  assetSpecs: {},
);

const product = Product(
  id: 'p',
  categoryId: 'c',
  name: 'p',
  description: '',
  basePrice: 1000,
  imageAssetId: 'i',
  isAvailable: true,
  defaults: [
    ProductIngredient(
      ingredientId: 'x',
      qty: 1,
      removable: true,
      refundOnRemove: true,
      refundAmount: 5000,
    ),
  ],
);

const ingredients = {
  'x': Ingredient(
    id: 'x',
    name: 'x',
    assetId: 'a',
    extraPrice: 3000,
    isAvailable: true,
  ),
};

Selection sel(Map<String, int> q) => Selection(
  productId: 'p',
  categoryId: 'c',
  definitionVersion: 1,
  ingredients: q,
);

void main() {
  test('price never goes below zero after refunds', () {
    const cheap = Product(
      id: 'p',
      categoryId: 'c',
      name: 'p',
      description: '',
      basePrice: 1000,
      imageAssetId: 'i',
      isAvailable: true,
      defaults: [
        ProductIngredient(
          ingredientId: 'x',
          qty: 1,
          removable: true,
          refundOnRemove: true,
          refundAmount: 5000,
        ),
      ],
    );
    final r = priceItem(
      definition: def,
      product: cheap,
      ingredients: ingredients,
      selection: sel({}),
      itemQty: 2,
    );
    expect(r.unitSubtotal, 1000 - 3000, reason: 'refund capped at extra price');
    expect(r.total, 0);
  });

  test('item quantity multiplies before the single rounding', () {
    final r = priceItem(
      definition: def,
      product: product,
      ingredients: ingredients,
      selection: sel({'x': 1}),
      itemQty: 3,
    );
    expect(r.total, 3000);
    expect(r.itemQty, 3);
  });

  test('bad quantity and disallowed extras are rejected', () {
    expect(
      () => priceItem(
        definition: def,
        product: product,
        ingredients: ingredients,
        selection: sel({'x': 1}),
        itemQty: 0,
      ),
      throwsA(isA<PricingException>()),
    );
    expect(
      () => priceItem(
        definition: def,
        product: product,
        ingredients: ingredients,
        selection: sel({'x': 1, 'ghost': 1}),
        itemQty: 1,
      ),
      throwsA(
        isA<PricingException>().having((e) => e.code, 'code', 'notAllowed'),
      ),
    );
  });
}
