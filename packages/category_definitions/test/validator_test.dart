import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:test/test.dart';

// TEMP fixtures, not owner data.
CategoryDefinition def({
  String strategy = 'scatter',
  List<StepSpec> animation = const [StepSpec(step: 'Oven')],
  List<String> allowed = const ['i1'],
  int maxQty = 2,
  List<SizeOption> sizes = const [SizeOption(id: 's', name: 'S')],
  List<OptionGroup> groups = const [],
  String baseAsset = 'base',
  Map<String, int> layerOverrides = const {},
  Map<String, String> byIngredient = const {},
  Map<String, num> params = const {},
  List<ProductGroup> productGroups = const [],
  List<AddOnGroup> addOnGroups = const [],
}) => CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'TEMP',
  base: BaseSpec(shape: 'circle', rawAssetId: baseAsset),
  allowedIngredientIds: allowed,
  placement: PlacementSpec(
    strategy: strategy,
    params: params,
    byIngredient: byIngredient,
  ),
  constraints: CustomizationConstraints(maxQty: maxQty),
  sizes: sizes,
  optionGroups: groups,
  animation: animation,
  assetSpecs: const {},
  layerOverrides: layerOverrides,
  productGroups: productGroups,
  addOnGroups: addOnGroups,
);

List<String> check(CategoryDefinition d) => validateDefinition(
  d,
  placementStrategies: {'scatter'},
  animationSteps: {'Oven', 'Swap'},
  assetIds: {'base', 'base2'},
  ingredientIds: {'i1', 'i2'},
).map((i) => i.path).toList();

void main() {
  test('a consistent definition has no issues', () {
    expect(check(def()), isEmpty);
  });

  test('missing asset is rejected', () {
    expect(check(def(baseAsset: 'nope')), ['base.rawAssetId']);
    const g = OptionGroup(
      id: 'g',
      name: 'g',
      defaultChoiceId: 'a',
      choices: [
        OptionChoice(
          id: 'a',
          name: 'a',
          base: BaseSpec(shape: 'circle', rawAssetId: 'x'),
        ),
      ],
    );
    expect(check(def(groups: const [g])), [
      'optionGroups[0].choices[0].base.rawAssetId',
    ]);
  });

  test('a base surface outside (0, 1] is rejected', () {
    OptionGroup crust(double surface) => OptionGroup(
      id: 'g',
      name: 'g',
      defaultChoiceId: 'a',
      choices: [
        OptionChoice(
          id: 'a',
          name: 'a',
          base: BaseSpec(
            shape: 'circle',
            rawAssetId: 'base2',
            surface: surface,
          ),
        ),
      ],
    );
    expect(check(def(groups: [crust(0.84)])), isEmpty);
    expect(check(def(groups: [crust(0)])), [
      'optionGroups[0].choices[0].base.surface',
    ]);
    expect(check(def(groups: [crust(1.2)])), [
      'optionGroups[0].choices[0].base.surface',
    ]);
  });

  test('unregistered step or strategy is rejected', () {
    expect(check(def(strategy: 'spiral')), ['placement.strategy']);
    expect(check(def(animation: const [StepSpec(step: 'Fold')])), [
      'animation[0].step',
    ]);
    expect(check(def(animation: const [])), ['animation']);
  });

  test('per-ingredient strategy must be registered and allowed', () {
    expect(check(def(byIngredient: {'i1': 'scatter'})), isEmpty);
    expect(check(def(byIngredient: {'i1': 'nope'})), [
      'placement.byIngredient.i1',
    ]);
    expect(check(def(byIngredient: {'i9': 'scatter'})), [
      'placement.byIngredient.i9',
    ]);
  });

  test('allowed ingredient that is not defined is rejected', () {
    expect(check(def(allowed: const ['i1', 'ghost'])), [
      'allowedIngredientIds',
    ]);
    expect(check(def(layerOverrides: const {'i2': 3})), ['layerOverrides.i2']);
  });

  test('conflicting limits are rejected', () {
    expect(check(def(maxQty: 0)), ['constraints.maxQty']);
    expect(
      check(
        def(
          sizes: const [
            SizeOption(id: 's', name: 'S'),
            SizeOption(id: 's', name: 'S2'),
          ],
        ),
      ),
      ['sizes[1].id'],
    );
    const g = OptionGroup(
      id: 'g',
      name: 'g',
      defaultChoiceId: 'zz',
      choices: [OptionChoice(id: 'a', name: 'a')],
    );
    expect(check(def(groups: const [g])), ['optionGroups[0].defaultChoiceId']);
  });

  test('loader refuses invalid definitions (fail-closed)', () {
    final r = loadBundledDefinitions(
      placementStrategies: const {'none'},
      animationSteps: const {'Oven', 'Swap', 'FlyToCart'},
    );
    expect(r.definitions, isEmpty);
    expect(r.rejected, isNotEmpty);
    for (final reasons in r.rejected.values) {
      expect(reasons, contains('placement.strategy'));
    }
  });

  test('add-on groups offer allowed ingredients to known product groups', () {
    const groups = [ProductGroup(id: 'sweet', name: 'Sweet')];
    AddOnGroup group({
      String id = 'sauces',
      List<String> ingredients = const ['i1'],
      List<String> productGroups = const ['sweet'],
    }) => AddOnGroup(
      id: id,
      name: 'Sauces',
      ingredientIds: ingredients,
      productGroupIds: productGroups,
    );
    expect(check(def(productGroups: groups, addOnGroups: [group()])), isEmpty);
    expect(
      check(
        def(
          productGroups: groups,
          addOnGroups: [
            group(ingredients: ['i2']),
            group(productGroups: ['savory']),
            group(id: 'empty', ingredients: []),
          ],
        ),
      ),
      [
        'addOnGroups[0].ingredientIds',
        'addOnGroups[1].id',
        'addOnGroups[1].productGroupIds',
        'addOnGroups[2].ingredientIds',
      ],
    );
  });

  test('an add-on ingredient has one tile on any product', () {
    const groups = [
      ProductGroup(id: 'sweet', name: 'Sweet'),
      ProductGroup(id: 'savory', name: 'Savory'),
    ];
    AddOnGroup g(String id, List<String> ingredients, [List<String>? only]) =>
        AddOnGroup(
          id: id,
          name: id,
          ingredientIds: ingredients,
          productGroupIds: only ?? const [],
        );
    List<String> addOns(List<AddOnGroup> addOnGroups) => check(
      def(
        allowed: const ['i1', 'i2'],
        productGroups: groups,
        addOnGroups: addOnGroups,
      ),
    );

    // Listed twice in one group.
    expect(
      addOns([
        g('a', ['i1', 'i2', 'i1']),
      ]),
      ['addOnGroups[0].ingredientIds[2]'],
    );
    // In two groups offered to every product.
    expect(
      addOns([
        g('a', ['i1']),
        g('b', ['i2', 'i1']),
      ]),
      ['addOnGroups[1].ingredientIds[1]'],
    );
    // One offered to every product, the other to a product group.
    expect(
      addOns([
        g('a', ['i1'], ['sweet']),
        g('b', ['i1']),
      ]),
      ['addOnGroups[1].ingredientIds[0]'],
    );
    expect(
      addOns([
        g('a', ['i1']),
        g('b', ['i1'], ['savory']),
      ]),
      ['addOnGroups[1].ingredientIds[0]'],
    );
    // Both offered to a shared product group.
    expect(
      addOns([
        g('a', ['i1'], ['sweet']),
        g('b', ['i1'], ['savory', 'sweet']),
      ]),
      ['addOnGroups[1].ingredientIds[0]'],
    );
    // Reported once per group, naming the first group it repeats.
    expect(
      addOns([
        g('a', ['i1']),
        g('b', ['i1']),
        g('c', ['i1']),
      ]),
      ['addOnGroups[1].ingredientIds[0]', 'addOnGroups[2].ingredientIds[0]'],
    );
    expect(
      validateDefinition(
        def(
          addOnGroups: [
            g('a', ['i1']),
            g('b', ['i1']),
          ],
        ),
      ).single.message,
      contains('addOnGroups[0] ("a")'),
    );
    // Groups no product is offered together may share an ingredient.
    expect(
      addOns([
        g('a', ['i1'], ['sweet']),
        g('b', ['i1'], ['savory']),
      ]),
      isEmpty,
    );
  });

  test('product and add-on groups are named in every language', () {
    expect(
      check(
        def(
          productGroups: const [
            ProductGroup(id: 'a', name: 'A', names: {'en': 'A', 'ar': 'أ'}),
            ProductGroup(id: 'b', name: ' ', names: {'en': 'B', 'ar': ''}),
          ],
          addOnGroups: const [
            AddOnGroup(
              id: 's',
              name: '',
              names: {'en': ' '},
              ingredientIds: ['i1'],
            ),
          ],
        ),
      ),
      [
        'productGroups[1].name',
        'productGroups[1].names.ar',
        'addOnGroups[0].name',
        'addOnGroups[0].names.en',
      ],
    );
  });

  test('the area the pieces fill has a size', () {
    List<String> placed(Map<String, num> params) => check(def(params: params));
    expect(
      placed(const {
        'radius': 0.8,
        'bandWidth': 0.3,
        'radius:i1': 0.7,
        'bandWidth:i1': 0.2,
      }),
      isEmpty,
    );
    // Other params may still be 0.
    expect(placed(const {'inset': 0, 'angle:i1': 0, 'offsetY': 0}), isEmpty);
    expect(
      placed(const {
        'radius': 0,
        'bandWidth': 0,
        'radius:i1': 0,
        'bandWidth:i1': -0.1,
        'inset': -1,
      }),
      [
        'placement.params.radius',
        'placement.params.bandWidth',
        'placement.params.radius:i1',
        'placement.params.bandWidth:i1',
        'placement.params.inset',
      ],
    );
  });
}
