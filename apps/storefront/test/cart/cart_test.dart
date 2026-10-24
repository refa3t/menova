import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/features/cart/domain/cart.dart';
import 'package:storefront/features/cart/domain/cart_line_view.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/menu/domain/menu.dart';

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'C',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base'),
  allowedIngredientIds: ['cheese', 'olive', 'pepper'],
  placement: PlacementSpec(strategy: 'scatter'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [SizeOption(id: 's', name: 'صغير')],
  optionGroups: [],
  animation: [StepSpec(step: 'Oven')],
  assetSpecs: {},
);

const product = Product(
  id: 'p1',
  categoryId: 'cat',
  name: 'P',
  description: '',
  basePrice: 10000,
  imageAssetId: 'final_p1',
  isAvailable: true,
  defaults: [
    ProductIngredient(ingredientId: 'cheese', qty: 1, removable: false),
    ProductIngredient(ingredientId: 'olive', qty: 1, removable: true),
  ],
);

Ingredient ing(String id, {bool available = true}) => Ingredient(
  id: id,
  name: 'n_$id',
  assetId: 'a_$id',
  extraPrice: 1500,
  isAvailable: available,
);

Menu menu({bool pepperAvailable = true}) => Menu.assemble(
  definitions: {'cat': def},
  contents: const [
    CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
  ],
  products: const [product],
  ingredients: [
    ing('cheese'),
    ing('olive'),
    ing('pepper', available: pepperAvailable),
  ],
  assets: const [],
);

Selection sel(Map<String, int> q) => Selection(
  productId: 'p1',
  categoryId: 'cat',
  definitionVersion: 1,
  sizeId: 's',
  ingredients: q,
);

void main() {
  Future<ProviderContainer> container() async {
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('cart survives a reload (P1-E03)', () async {
    final first = await container();
    first.read(cartProvider.notifier).add(sel({'cheese': 1}), qty: 2);
    first.dispose();
    final second = await container();
    addTearDown(second.dispose);
    expect(second.read(cartProvider).itemCount, 2);
  });

  test('a corrupt saved cart yields an empty cart', () async {
    SharedPreferences.setMockInitialValues({'cart.v1': '{not json'});
    final c = await container();
    addTearDown(c.dispose);
    expect(c.read(cartProvider).lines, isEmpty);
  });

  test('add is one atomic step and replace keeps the same line', () async {
    final c = await container();
    addTearDown(c.dispose);
    final cart = c.read(cartProvider.notifier);
    final id = cart.add(sel({'cheese': 1, 'olive': 1}));
    expect(c.read(cartProvider).lines, hasLength(1));
    cart.replace(id, sel({'cheese': 1}));
    final lines = c.read(cartProvider).lines;
    expect(lines, hasLength(1), reason: 'editing never duplicates (AC-18)');
    expect(lines.single.lineId, id);
    expect(lines.single.selection.qtyOf('olive'), 0);
  });

  test('qty below one removes the line', () {
    final cart = Cart.empty.add(
      CartLine(lineId: 'l', selection: sel({}), qty: 2),
    );
    expect(cart.setQty('l', 3).itemCount, 3);
    expect(cart.setQty('l', 0).lines, isEmpty);
  });

  test('line view shows size, extras and removed defaults with a price', () {
    final v = CartLineView.resolve(
      CartLine(lineId: 'l', selection: sel({'cheese': 1, 'pepper': 1}), qty: 2),
      menu(),
    );
    expect(v.available, isTrue);
    expect(v.sizeName, 'صغير');
    expect(v.extras, [('n_pepper', 1)]);
    expect(v.removed, ['n_olive']);
    expect(v.price!.total, (10000 + 1500) * 2);
  });

  test('a line with an extra that became unavailable is flagged', () {
    final v = CartLineView.resolve(
      CartLine(
        lineId: 'l',
        selection: sel({'cheese': 1, 'olive': 1, 'pepper': 1}),
        qty: 1,
      ),
      menu(pepperAvailable: false),
    );
    expect(v.available, isFalse);
  });

  test('cart JSON round-trips', () {
    final cart = Cart.empty.add(
      CartLine(lineId: 'l', selection: sel({'cheese': 1}), qty: 2),
    );
    final back = Cart.fromJson(cart.toJson());
    expect(back.lines.single.selection, cart.lines.single.selection);
    expect(back.lines.single.qty, 2);
  });
}
