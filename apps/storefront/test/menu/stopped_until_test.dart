import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/builder/presentation/builder_providers.dart';
import 'package:storefront/features/cart/domain/cart.dart';
import 'package:storefront/features/cart/domain/cart_line_view.dart';
import 'package:storefront/features/checkout/domain/order_builder.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';

import '../cart/cart_test.dart' show def, ing, product, sel;

// «إيقاف لنهاية اليوم»: a record stopped until a time is unavailable before
// it and comes back by itself after, without a reload.

Ingredient pepperUntil(int? until) => Ingredient(
  id: 'pepper',
  name: 'n_pepper',
  assetId: 'a_pepper',
  extraPrice: 1500,
  isAvailable: true,
  unavailableUntil: until,
);

Product productUntil(int? until) => Product(
  id: product.id,
  categoryId: product.categoryId,
  name: product.name,
  description: product.description,
  basePrice: product.basePrice,
  imageAssetId: product.imageAssetId,
  isAvailable: true,
  defaults: product.defaults,
  unavailableUntil: until,
);

MenuSource source({int? productUntilMs, int? pepperUntilMs}) => MenuSource(
  definitions: const {'cat': def},
  contents: const [
    CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
  ],
  products: [productUntil(productUntilMs)],
  ingredients: [ing('cheese'), ing('olive'), pepperUntil(pepperUntilMs)],
  assets: const [],
);

void main() {
  final now = DateTime(2026, 11, 27, 22);
  final dayEnd = DateTime(2026, 11, 28, 4);
  final until = dayEnd.millisecondsSinceEpoch;

  test('a product stopped until the day end is hidden, then back', () {
    final s = source(productUntilMs: until);
    expect(s.at(now).categories.single.products, isEmpty);
    expect(s.at(now).nextAvailabilityChange, dayEnd);
    final after = s.at(dayEnd);
    expect(after.categories.single.products.single.id, 'p1');
    expect(after.nextAvailabilityChange, isNull);
  });

  test('an ingredient stopped until a time is unavailable before it', () {
    final s = source(pepperUntilMs: until);
    expect(s.at(now).ingredientAvailable('pepper'), isFalse);
    expect(s.at(dayEnd).ingredientAvailable('pepper'), isTrue);
    expect(s.at(now).ingredientAvailable('unknown'), isFalse);
  });

  test('cart flags it and checkout refuses it at submit time', () {
    final s = source(pepperUntilMs: until);
    final cart = Cart.empty.add(
      CartLine(
        lineId: 'l1',
        selection: sel({'cheese': 1, 'pepper': 1}),
        qty: 1,
      ),
    );
    final line = cart.lines.single;
    expect(CartLineView.resolve(line, s.at(now)).available, isFalse);
    expect(
      () => OrderBuilder.items(cart, s.at(now)),
      throwsA(isA<OrderBuildException>()),
    );
    expect(CartLineView.resolve(line, s.at(dayEnd)).available, isTrue);
    expect(OrderBuilder.items(cart, s.at(dayEnd)), hasLength(1));
  });

  test('the builder keeps what the guest built when the clock moves', () async {
    final c = ProviderContainer(
      overrides: [
        menuSourceProvider.overrideWith(
          (ref) async => source(pepperUntilMs: until),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(menuProvider, (_, _) {});
    await c.read(menuProvider.future);
    const key = (productId: 'p1', lineId: null);
    final sub = c.listen(builderProvider(key), (_, _) {});
    addTearDown(sub.close);
    expect(c.read(builderProvider(key).notifier).add('cheese'), isNull);
    expect(c.read(builderProvider(key)).canAdd('pepper'), isFalse);
    c.read(availabilityClockProvider.notifier).tick();
    await c.read(menuProvider.future);
    expect(c.read(builderProvider(key)).qtyOf('cheese'), 2);
  });

  test('the shown menu updates by itself when the time passes', () async {
    final soon = DateTime.now()
        .add(const Duration(milliseconds: 150))
        .millisecondsSinceEpoch;
    final c = ProviderContainer(
      overrides: [
        menuSourceProvider.overrideWith(
          (ref) async => source(productUntilMs: soon),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(menuProvider, (_, _) {});
    addTearDown(sub.close);
    final before = await c.read(menuProvider.future);
    expect(before.categories.single.products, isEmpty);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final after = await c.read(menuProvider.future);
    expect(after.categories.single.products.single.id, 'p1');
    expect(after.nextAvailabilityChange, isNull);
  });
}
