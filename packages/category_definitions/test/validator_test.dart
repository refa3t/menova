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
}) => CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'TEMP',
  base: BaseSpec(shape: 'circle', rawAssetId: baseAsset),
  allowedIngredientIds: allowed,
  placement: PlacementSpec(strategy: strategy),
  constraints: CustomizationConstraints(maxQty: maxQty),
  sizes: sizes,
  optionGroups: groups,
  animation: animation,
  assetSpecs: const {},
  layerOverrides: layerOverrides,
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

  test('unregistered step or strategy is rejected', () {
    expect(check(def(strategy: 'spiral')), ['placement.strategy']);
    expect(check(def(animation: const [StepSpec(step: 'Fold')])), [
      'animation[0].step',
    ]);
    expect(check(def(animation: const [])), ['animation']);
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
    expect(r.rejected.values.single, contains('placement.strategy'));
  });
}
