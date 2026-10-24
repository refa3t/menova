import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'cat',
  definitionVersion: 4,
  name: 'TEMP',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base'),
  allowedIngredientIds: ['cheese', 'olive', 'pepper', 'off'],
  placement: PlacementSpec(strategy: 'scatter'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [
    SizeOption(id: 's', name: 'S'),
    SizeOption(id: 'l', name: 'L'),
  ],
  optionGroups: [
    OptionGroup(
      id: 'dough',
      name: 'D',
      defaultChoiceId: 'regular',
      choices: [
        OptionChoice(id: 'regular', name: 'R'),
        OptionChoice(
          id: 'thin',
          name: 'T',
          base: BaseSpec(shape: 'circle', rawAssetId: 'base_thin'),
        ),
      ],
    ),
  ],
  animation: [StepSpec(step: 'Oven')],
  assetSpecs: {},
);

const product = Product(
  id: 'p1',
  categoryId: 'cat',
  name: 'TEMP',
  description: '',
  basePrice: 100,
  imageAssetId: 'final_p1',
  isAvailable: true,
  defaults: [
    ProductIngredient(ingredientId: 'cheese', qty: 2, removable: false),
    ProductIngredient(ingredientId: 'olive', qty: 1, removable: true),
  ],
);

BuilderState open() => BuilderState.open(
  definition: def,
  product: product,
  unavailableIngredientIds: {'off'},
);

void main() {
  test('opens with defaults, first size and default options', () {
    final s = open();
    expect(s.selection.ingredients, {'cheese': 2, 'olive': 1});
    expect(s.selection.sizeId, 's');
    expect(s.selection.options, {'dough': 'regular'});
    expect(s.selection.definitionVersion, 4);
    expect(s.isModified, isFalse);
  });

  test('adding above a default counts as an extra', () {
    final r = open().add('cheese');
    expect(r.accepted, isTrue);
    expect(r.state.extras, {'cheese': 1});
    expect(r.state.isModified, isTrue);
  });

  test('removing a removable default records "without"', () {
    final r = open().remove('olive');
    expect(r.state.removed, ['olive']);
  });

  test('a non-removable default cannot go below its default qty', () {
    final up = open().add('cheese').state;
    expect(up.remove('cheese').accepted, isTrue, reason: 'extra can go');
    final r = open().remove('cheese');
    expect(r.rejection, BuilderRejection.notRemovable);
    expect(r.state.qtyOf('cheese'), 2);
  });

  test('maxQty is enforced with a rejection', () {
    var s = open();
    s = s.add('pepper').state.add('pepper').state;
    final r = s.add('pepper');
    expect(r.rejection, BuilderRejection.maxQty);
    expect(r.state.qtyOf('pepper'), 2);
  });

  test('not allowed or unavailable ingredients are refused', () {
    expect(open().add('ham').rejection, BuilderRejection.notAllowed);
    expect(open().add('off').rejection, BuilderRejection.unavailable);
  });

  test('size and option changes are validated', () {
    expect(open().selectSize('l').state.selection.sizeId, 'l');
    expect(open().selectSize('xl').rejection, BuilderRejection.unknownChoice);
    expect(
      open().selectOption('dough', 'thin').state.selection.options['dough'],
      'thin',
    );
    expect(
      open().selectOption('dough', 'stuffed').rejection,
      BuilderRejection.unknownChoice,
    );
  });

  test('reset returns to the untouched product', () {
    final s = open().add('pepper').state.remove('olive').state.reset();
    expect(s.selection, open().selection);
  });

  test('restore keeps a saved selection (editing a cart line)', () {
    final saved = open().add('pepper').state.selection;
    final s = BuilderState.restore(
      definition: def,
      product: product,
      selection: saved,
    );
    expect(s.qtyOf('pepper'), 1);
  });

  test('chosen option base replaces the category base; size sets scale', () {
    expect(open().activeBase.rawAssetId, 'base');
    final thin = open().selectOption('dough', 'thin').state;
    expect(thin.activeBase.rawAssetId, 'base_thin');
    expect(open().sizeScale, 1);
  });
}
