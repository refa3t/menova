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

  group('price caps', () {
    test('every size costs above zero and at most 1000 EGP', () {
      expect(PriceCaps.maxProductPrice, 100000);
      // Exactly 1000 EGP: the base price, and the base plus a size's delta.
      expect(check(product(basePrice: 100000)), isEmpty);
      expect(
        check(product(basePrice: 90000, sizeDeltas: {'s': 10000})),
        isEmpty,
      );
      // 1000.01 EGP.
      expect(check(product(basePrice: 100001)), ['basePrice']);
      expect(check(product(basePrice: 90000, sizeDeltas: {'s': 10001})), [
        'sizeDeltas.s',
      ]);
      // A base price over the cap is reported once, not on each size too.
      expect(check(product(basePrice: 100001, sizeDeltas: {'s': 500})), [
        'basePrice',
      ]);
      expect(check(product(basePrice: -100)), ['basePrice']);
    });

    test('an option delta is 0 to 200 EGP', () {
      expect(PriceCaps.maxOptionDelta, 20000);
      expect(check(product(optionDeltas: {'a': 20000})), isEmpty);
      expect(check(product(optionDeltas: {'a': 20001})), ['optionDeltas.a']);
      expect(check(product(optionDeltas: {'a': -1})), ['optionDeltas.a']);
    });

    test('every bundled definition fits the rules\' price counts', () {
      final defs = loadBundledDefinitions().definitions.values;
      expect(defs, isNotEmpty);
      for (final d in defs) {
        expect(
          d.sizes.length,
          lessThanOrEqualTo(PriceCaps.maxSizePrices),
          reason: d.id,
        );
        expect(
          [for (final g in d.optionGroups) ...g.choices].length,
          lessThanOrEqualTo(PriceCaps.maxOptionPrices),
          reason: d.id,
        );
      }
    });
  });

  group('a group where add-ons depend on it', () {
    CategoryDefinition offering(List<String> productGroupIds) =>
        CategoryDefinition.fromJson({
          ...def.toJson(),
          'addOnGroups': [
            AddOnGroup(
              id: 'sauces',
              name: 'TEMP',
              ingredientIds: const ['i2'],
              productGroupIds: productGroupIds,
            ).toJson(),
          ],
        });
    List<String> paths(Product p, CategoryDefinition d) => [
      for (final i in validateProduct(p, d)) i.path,
    ];

    test('is required when an add-on group is limited to groups', () {
      final limited = offering(['grp']);
      expect(productGroupRequired(limited), isTrue);
      expect(paths(product(groupId: null), limited), ['groupId']);
      expect(paths(product(), limited), isEmpty);
    });

    test('is optional when every add-on group is open to all', () {
      final open = offering(const []);
      expect(productGroupRequired(open), isFalse);
      expect(productGroupRequired(def), isFalse);
      expect(paths(product(groupId: null), open), isEmpty);
      expect(paths(product(groupId: null), def), isEmpty);
    });

    test('follows the bundled definitions', () {
      final defs = loadBundledDefinitions().definitions;
      // Crepe sauces are offered by group (savory/sweet); pizza's to all.
      expect(productGroupRequired(defs['crepe']!), isTrue);
      expect(productGroupRequired(defs['pizza']!), isFalse);
    });
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
    });

    test('the extra price is above zero and at most 200 EGP', () {
      List<String> priced(int p) =>
          ing(Ingredient.fromJson({...ok.toJson(), 'extraPrice': p}));
      expect(priced(1), isEmpty);
      expect(priced(PriceCaps.maxExtraPrice), isEmpty);
      expect(PriceCaps.maxExtraPrice, 20000);
      expect(priced(20001), ['extraPrice']); // 200.01 EGP
      expect(priced(0), ['extraPrice']);
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

    test('a stop until a time is accepted, a bad one refused', () {
      List<String> until(int u) =>
          ing(Ingredient.fromJson({...ok.toJson(), 'unavailableUntil': u}));
      expect(until(1764302400000), isEmpty);
      expect(until(0), ['unavailableUntil']);
    });
  });

  test('a product stopped until a time is valid, a bad time refused', () {
    List<String> until(int u) =>
        check(Product.fromJson({...product().toJson(), 'unavailableUntil': u}));
    expect(until(1764302400000), isEmpty);
    expect(until(-5), ['unavailableUntil']);
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

  test('the catalog check lists every product and ingredient problem', () {
    const ok = Ingredient(
      id: 'i1',
      name: 'TEMP',
      assetId: 'ing_i1',
      extraPrice: 1500,
      isAvailable: true,
    );
    final findings = checkCatalog(
      definitions: {'cat': def},
      products: [
        product(),
        Product.fromJson({...product().toJson(), 'id': 'p2', 'basePrice': 0}),
        Product.fromJson({
          ...product().toJson(),
          'id': 'p3',
          'categoryId': 'x',
        }),
      ],
      ingredients: {
        'i1': ok,
        'i2': Ingredient.fromJson({
          ...ok.toJson(),
          'id': 'i2',
          'assetId': 'zz',
        }),
      },
      ingredientAssets: {'ing_i1'},
    );
    expect(findings.map((f) => '${f.kind}:${f.id}'), [
      'product:p2',
      'product:p3',
      'ingredient:i2',
    ]);
  });

  test('offers and coupons stay within the rules (P3-09)', () {
    List<String> paths(Offer o) => [
      for (final i in validateOffer(o, categoryIds: {'cat'})) i.path,
    ];
    const ok = Offer(
      id: 'o1',
      name: 'TEMP offer',
      kind: OfferKind.percent,
      value: 10,
    );
    expect(paths(ok), isEmpty);
    expect(
      paths(
        const Offer(
          id: 'c',
          name: 'TEMP',
          kind: OfferKind.amount,
          value: 2000,
          categoryId: 'cat',
          code: 'EID-26',
          maxUses: 50,
        ),
      ),
      isEmpty,
    );
    expect(
      paths(
        const Offer(id: 'o', name: 'x', kind: OfferKind.percent, value: 10),
      ),
      ['name'],
    );
    expect(
      paths(
        const Offer(id: 'o', name: 'TEMP', kind: OfferKind.percent, value: 0),
      ),
      ['value'],
    );
    expect(
      paths(
        const Offer(id: 'o', name: 'TEMP', kind: OfferKind.amount, value: 50),
      ),
      ['value'],
    );
    expect(
      paths(
        const Offer(
          id: 'o',
          name: 'TEMP',
          kind: OfferKind.freeDelivery,
          value: 5,
        ),
      ),
      ['value'],
    );
    expect(
      paths(
        const Offer(
          id: 'o',
          name: 'TEMP',
          kind: OfferKind.percent,
          value: 5,
          categoryId: 'other',
        ),
      ),
      ['categoryId'],
    );
    expect(
      paths(
        const Offer(
          id: 'o',
          name: 'TEMP',
          kind: OfferKind.percent,
          value: 5,
          startsAtMs: 10,
          endsAtMs: 10,
        ),
      ),
      ['endsAtMs'],
    );
    expect(
      paths(
        const Offer(
          id: 'o',
          name: 'TEMP',
          kind: OfferKind.percent,
          value: 5,
          maxDiscount: 50,
        ),
      ),
      ['maxDiscount'],
    );
    expect(
      paths(
        const Offer(
          id: 'o',
          name: 'TEMP',
          kind: OfferKind.percent,
          value: 5,
          maxUses: 3,
        ),
      ),
      ['maxUses'],
    );
    expect(
      paths(
        const Offer(
          id: 'c',
          name: 'TEMP',
          kind: OfferKind.percent,
          value: 5,
          code: 'eid',
        ),
      ),
      ['code'],
    );
  });
}
