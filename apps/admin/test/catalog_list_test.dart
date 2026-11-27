import 'package:admin/features/catalog/domain/catalog_list.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Product product(
  String id, {
  String category = 'cat',
  bool available = true,
  String name = 'TEMP',
  Map<String, String> names = const {},
  Map<String, int> sizeDeltas = const {},
}) => Product(
  id: id,
  categoryId: category,
  name: name,
  names: names,
  description: '',
  basePrice: 13000,
  imageAssetId: 'final_$id',
  defaults: const [],
  isAvailable: available,
  sizeDeltas: sizeDeltas,
);

Ingredient ingredient(String id, {bool available = true, String? ar}) =>
    Ingredient(
      id: id,
      name: ar ?? id,
      names: {'ar': ?ar},
      assetId: 'ing_$id',
      extraPrice: 1500,
      isAvailable: available,
    );

/// Any bundled definition, as JSON, to override a field of.
Json sampleDefinition() =>
    loadBundledDefinitions().definitions.values.first.toJson();

void main() {
  test('batches hold at most maxChangesPerBatch, in order', () {
    final items = List.generate(23, (i) => i);
    final chunks = chunked(items);
    expect(chunks.map((c) => c.length), [10, 10, 3]);
    expect(chunks.expand((c) => c), items);
    expect(chunked(<int>[]), isEmpty);
    // Two writes per change (the document and its audit entry): far below
    // Firestore's 500 writes, and within the rules' 20 document reads.
    expect(maxChangesPerBatch * 2, lessThanOrEqualTo(500));
    expect(maxChangesPerBatch, lessThanOrEqualTo(20));
  });

  test(
    'bulk product availability: one audited save per product that changes',
    () {
      final on = product('p1');
      final off = product('p2', available: false);
      final changes = productAvailabilityChanges([on, off], false);
      expect(changes, hasLength(1)); // p2 is already stopped
      final c = changes.single;
      expect(c.action, 'saveProduct');
      expect(c.path, 'products/p1');
      expect(c.before, on.toJson());
      expect(c.after, {...on.toJson(), 'isAvailable': false});
      expect(
        productAvailabilityChanges([on, off], true).single.path,
        'products/p2',
      );
    },
  );

  test('bulk ingredient availability: same shape as the single switch', () {
    final i = ingredient('i1');
    final c = ingredientAvailabilityChanges([i], false).single;
    expect(c.action, 'saveIngredient');
    expect(c.path, 'ingredients/i1');
    expect(c.after, {...i.toJson(), 'isAvailable': false});
    expect(ingredientAvailabilityChanges([i], true), isEmpty);
  });

  test('products filter by category, status, draft and search', () {
    final all = [
      product('a', name: 'Ù…Ø§Ø±Ø¬Ø±ÙŠØªØ§', names: {'en': 'Margherita'}),
      product('b', available: false, name: 'ØªÙˆÙ†Ø©'),
      product('c', category: 'crepe', name: 'ÙƒØ±ÙŠØ¨'),
    ];
    List<String> ids(List<Product> ps) => [for (final p in ps) p.id];
    expect(ids(filterProducts(all, categoryId: 'cat')), ['a', 'b']);
    expect(ids(filterProducts(all, status: StatusFilter.stopped)), ['b']);
    expect(ids(filterProducts(all, status: StatusFilter.available)), [
      'a',
      'c',
    ]);
    expect(
      ids(
        filterProducts(
          all,
          status: StatusFilter.drafted,
          draftTargets: {'products/c'},
        ),
      ),
      ['c'],
    );
    expect(ids(filterProducts(all, query: 'margh')), ['a']);
    expect(ids(filterProducts(all, query: 'ØªÙˆÙ†Ø©')), ['b']);
  });

  test('ingredients filter by the categories that allow them', () {
    final def = CategoryDefinition.fromJson({
      ...sampleDefinition(),
      'allowedIngredientIds': ['i1'],
    });
    final all = [ingredient('i1', ar: 'Ø¨'), ingredient('i2', ar: 'Ø£')];
    expect([for (final i in filterIngredients(all)) i.id], ['i2', 'i1']);
    expect(
      [for (final i in filterIngredients(all, category: def)) i.id],
      ['i1'],
    );
  });

  test('size prices follow the definition order, or the base price alone', () {
    final def = CategoryDefinition.fromJson({
      ...sampleDefinition(),
      'sizes': [
        {'id': 's', 'name': 'S'},
        {'id': 'm', 'name': 'M'},
        {'id': 'l', 'name': 'L'},
      ],
    });
    final p = product('p', sizeDeltas: {'l': 10000, 's': 0, 'm': 5000});
    expect(sizePrices(p, def), [13000, 18000, 23000]);
    expect(sizePrices(product('q'), def), [13000]);
    expect(sizePrices(p, null), [13000]);
  });
}
