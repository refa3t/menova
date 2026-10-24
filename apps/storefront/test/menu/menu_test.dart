import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/menu/domain/menu.dart';

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'cat_a',
  definitionVersion: 1,
  name: 'A',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base_a'),
  allowedIngredientIds: [],
  placement: PlacementSpec(strategy: 'scatter'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [],
  optionGroups: [],
  animation: [],
  assetSpecs: {},
);

Product product(
  String id, {
  int order = 0,
  bool available = true,
  String cat = 'cat_a',
}) => Product(
  id: id,
  categoryId: cat,
  name: id,
  description: '',
  basePrice: 100,
  imageAssetId: 'final_$id',
  defaults: const [],
  isAvailable: available,
  displayOrder: order,
);

Asset asset(String id) => Asset(
  id: id,
  kind: 'k',
  name: id,
  publicId: id,
  secureUrl: 'https://x/$id',
  version: 1,
  layerOrder: 0,
  allowedCategoryIds: const ['cat_a'],
);

void main() {
  test('categories without a definition or hidden never show', () {
    final menu = Menu.assemble(
      definitions: {'cat_a': def},
      contents: const [
        CategoryContent(categoryId: 'cat_a', isVisible: true, displayOrder: 0),
        CategoryContent(
          categoryId: 'unknown',
          isVisible: true,
          displayOrder: 1,
        ),
      ],
      products: [product('p1')],
      ingredients: const [],
      assets: const [],
    );
    expect(menu.categories.map((c) => c.definition.id), ['cat_a']);

    final hidden = Menu.assemble(
      definitions: {'cat_a': def},
      contents: const [
        CategoryContent(categoryId: 'cat_a', isVisible: false, displayOrder: 0),
      ],
      products: [product('p1')],
      ingredients: const [],
      assets: const [],
    );
    expect(hidden.categories, isEmpty);
  });

  test('products are filtered by availability and ordered', () {
    final menu = Menu.assemble(
      definitions: {'cat_a': def},
      contents: const [
        CategoryContent(categoryId: 'cat_a', isVisible: true, displayOrder: 0),
      ],
      products: [
        product('b', order: 2),
        product('a', order: 1),
        product('off', available: false),
      ],
      ingredients: const [],
      assets: const [],
    );
    expect(menu.categories.single.products.map((p) => p.id), ['a', 'b']);
  });

  test('card image falls back to the category base', () {
    final menu = Menu.assemble(
      definitions: {'cat_a': def},
      contents: const [],
      products: const [],
      ingredients: const [],
      assets: [asset('base_a'), asset('final_p2')],
    );
    expect(menu.cardImageUrl(product('p1'), def), 'https://x/base_a');
    expect(menu.cardImageUrl(product('p2'), def), 'https://x/final_p2');
  });
}
