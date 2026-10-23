import 'dart:convert';

import 'package:core/core.dart';
import 'package:test/test.dart';

// TEMP: illustrative test fixtures only, not owner-approved values.
const definitionJson = {
  'id': 'cat_a',
  'definitionVersion': 1,
  'name': 'TEMP category',
  'base': {
    'shape': 'circle',
    'rawAssetId': 'base_raw',
    'cookedAssetId': 'base_cooked',
  },
  'allowedIngredientIds': ['ing_1', 'ing_2'],
  'placement': {
    'strategy': 'scatter',
    'params': {'radius': 0.8},
  },
  'constraints': {'maxQty': 2},
  'sizes': [
    {'id': 's', 'name': 'TEMP S', 'scale': 0.8},
    {'id': 'm', 'name': 'TEMP M', 'scale': 1.0},
  ],
  'optionGroups': [
    {
      'id': 'grp',
      'name': 'TEMP group',
      'defaultChoiceId': 'c1',
      'choices': [
        {'id': 'c1', 'name': 'TEMP c1'},
        {
          'id': 'c2',
          'name': 'TEMP c2',
          'base': {'shape': 'circle', 'rawAssetId': 'base2_raw'},
        },
      ],
    },
  ],
  'animation': [
    {
      'step': 'stepA',
      'weight': 2.0,
      'params': {'k': 'v'},
    },
    {'step': 'stepB', 'weight': 1.0, 'params': <String, Object?>{}},
  ],
  'assetSpecs': {
    'base': {
      'formats': ['png', 'webp'],
      'maxBytes': 512000,
      'transparent': true,
    },
  },
  'layerOverrides': {'ing_1': 5},
};

const productJson = {
  'id': 'p1',
  'categoryId': 'cat_a',
  'name': 'TEMP product',
  'description': '',
  'basePrice': 10000,
  'imageAssetId': 'final_p1',
  'defaults': [
    {
      'ingredientId': 'ing_1',
      'qty': 2,
      'removable': false,
      'refundOnRemove': false,
      'refundAmount': 0,
    },
  ],
  'isAvailable': true,
  'sizeDeltas': {'s': 0, 'm': 3000},
  'optionDeltas': {'c2': 1500},
  'displayOrder': 1,
};

const ingredientJson = {
  'id': 'ing_1',
  'name': 'TEMP ingredient',
  'assetId': 'a1',
  'extraPrice': 1500,
  'isAvailable': true,
  'sizeMultipliers': {'m': 1.5},
};

const assetJson = {
  'id': 'a1',
  'kind': 'ingredient',
  'name': 'TEMP asset',
  'publicId': 'abc',
  'secureUrl': 'https://res.cloudinary.com/x/image/upload/v1/abc.webp',
  'version': 1,
  'variants': ['https://res.cloudinary.com/x/image/upload/v1/abd.webp'],
  'layerOrder': 10,
  'allowedCategoryIds': ['cat_a'],
  'adminReplaceable': false,
};

/// Round-trips through a real JSON string to catch non-serializable fields.
Map<String, dynamic> viaString(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

void main() {
  test('CategoryDefinition round-trips', () {
    final d = CategoryDefinition.fromJson(viaString(definitionJson));
    expect(CategoryDefinition.fromJson(viaString(d.toJson())), d);
    expect(d.optionGroups.single.choices[1].base!.rawAssetId, 'base2_raw');
    expect(d.layerOverrides['ing_1'], 5);
  });

  test('Product, Ingredient, Asset, CategoryContent round-trip', () {
    final p = Product.fromJson(viaString(productJson));
    expect(Product.fromJson(viaString(p.toJson())), p);
    final i = Ingredient.fromJson(viaString(ingredientJson));
    expect(Ingredient.fromJson(viaString(i.toJson())), i);
    final a = Asset.fromJson(viaString(assetJson));
    expect(Asset.fromJson(viaString(a.toJson())), a);
    const c = CategoryContent(
      categoryId: 'cat_a',
      isVisible: true,
      displayOrder: 0,
    );
    expect(CategoryContent.fromJson(viaString(c.toJson())), c);
  });

  test('size multiplier defaults to 1', () {
    final i = Ingredient.fromJson(viaString(ingredientJson));
    expect(i.multiplierFor('m'), 1.5);
    expect(i.multiplierFor('s'), 1);
    expect(i.multiplierFor(null), 1);
  });

  test('missing or mistyped required fields are rejected', () {
    final noPrice = Map<String, dynamic>.of(productJson)..remove('basePrice');
    expect(() => Product.fromJson(noPrice), throwsFormatException);
    final floatPrice = Map<String, dynamic>.of(productJson)
      ..['basePrice'] = 100.5;
    expect(() => Product.fromJson(floatPrice), throwsFormatException);
  });
}
