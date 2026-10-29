import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:test/test.dart';

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'TEMP',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base'),
  allowedIngredientIds: ['i1', 'i2'],
  placement: PlacementSpec(strategy: 'scatter'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [SizeOption(id: 's', name: 'S')],
  optionGroups: [
    OptionGroup(
      id: 'g',
      name: 'G',
      defaultChoiceId: 'a',
      choices: [OptionChoice(id: 'a', name: 'A')],
    ),
  ],
  animation: [],
  assetSpecs: {},
  productGroups: [ProductGroup(id: 'grp', name: 'Group')],
);

Product product({
  String categoryId = 'cat',
  int basePrice = 10000,
  List<ProductIngredient> defaults = const [
    ProductIngredient(ingredientId: 'i1', qty: 1, removable: true),
  ],
  Map<String, int> sizeDeltas = const {'s': 0},
  Map<String, int> optionDeltas = const {'a': 0},
  String? groupId = 'grp',
}) => Product(
  id: 'p',
  categoryId: categoryId,
  name: 'P',
  description: '',
  basePrice: basePrice,
  imageAssetId: 'img',
  defaults: defaults,
  isAvailable: true,
  sizeDeltas: sizeDeltas,
  optionDeltas: optionDeltas,
  groupId: groupId,
);

List<String> check(Product p) => validateProduct(
  p,
  def,
  ingredientIds: {'i1', 'i2'},
).map((i) => i.path).toList();

void main() {
  test('a product within its definition is valid', () {
    expect(check(product()), isEmpty);
  });

  test('prices must be positive, deltas never negative', () {
    expect(check(product(basePrice: 0)), ['basePrice']);
    expect(check(product(sizeDeltas: {'s': -1})), ['sizeDeltas.s']);
  });

  test('only sizes, options and groups the definition offers', () {
    expect(check(product(sizeDeltas: {'xl': 5})), ['sizeDeltas.xl']);
    expect(check(product(optionDeltas: {'zz': 5})), ['optionDeltas.zz']);
    expect(check(product(groupId: 'nope')), ['groupId']);
    expect(check(product(categoryId: 'other')), ['categoryId']);
  });

  test('defaults: allowed, defined, once, at least one unit', () {
    expect(
      check(
        product(
          defaults: const [
            ProductIngredient(ingredientId: 'i1', qty: 1, removable: true),
            ProductIngredient(ingredientId: 'i1', qty: 1, removable: true),
          ],
        ),
      ),
      ['defaults[1]'],
    );
    expect(
      check(
        product(
          defaults: const [
            ProductIngredient(ingredientId: 'x', qty: 0, removable: true),
          ],
        ),
      ),
      ['defaults[0]', 'defaults[0]', 'defaults[0].qty'],
    );
  });

  group('ingredients (P3-03)', () {
    const ok = Ingredient(
      id: 'i1',
      name: 'TEMP',
      assetId: 'ing_i1',
      extraPrice: 1500,
      isAvailable: true,
    );
    List<String> ing(Ingredient i) => validateIngredient(
      i,
      ingredientAssets: {'ing_i1'},
    ).map((x) => x.path).toList();

    test('a priced ingredient with a known image is valid', () {
      expect(ing(ok), isEmpty);
      expect(
        ing(Ingredient.fromJson({...ok.toJson(), 'extraPrice': 0})),
        isEmpty,
      );
    });

    test('negative price, empty name, unknown image are refused', () {
      expect(ing(Ingredient.fromJson({...ok.toJson(), 'extraPrice': -1})), [
        'extraPrice',
      ]);
      expect(ing(Ingredient.fromJson({...ok.toJson(), 'name': ' '})), ['name']);
      expect(ing(Ingredient.fromJson({...ok.toJson(), 'assetId': 'x'})), [
        'assetId',
      ]);
    });
  });

  group('asset files (P3-04)', () {
    const spec = AssetSpec(
      formats: ['png', 'webp'],
      maxBytes: 150 * 1024,
      transparent: true,
    );
    List<String> file(String? format, int bytes, bool alpha) =>
        validateAssetFile(
          AssetFile(format: format, bytes: bytes, hasTransparency: alpha),
          spec,
        ).map((i) => i.path).toList();

    test('format is read from the content', () {
      expect(
        AssetFile.sniff([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
        'png',
      );
      expect(
        AssetFile.sniff([
          0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50, //
        ]),
        'webp',
      );
      expect(AssetFile.sniff([0xFF, 0xD8, 0xFF, 0xE0]), isNull); // jpeg
    });

    test('a transparent png or webp within size passes', () {
      expect(file('png', 100 * 1024, true), isEmpty);
      expect(file('webp', 150 * 1024, true), isEmpty);
    });

    test('wrong format, too big or opaque is refused', () {
      expect(file(null, 1000, true), ['format']);
      expect(file('png', 151 * 1024, true), ['bytes']);
      expect(file('png', 1000, false), ['transparent']);
    });
  });
}
