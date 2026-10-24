import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/features/orders/domain/order_transitions.dart';
import 'package:reception/features/orders/domain/order_verification.dart';

import 'orders_test.dart' show order;

// TEMP fixtures, not owner data.
const def = CategoryDefinition(
  id: 'c',
  definitionVersion: 1,
  name: 'c',
  base: BaseSpec(shape: 'circle', rawAssetId: 'b'),
  allowedIngredientIds: ['cheese', 'olive', 'pepper'],
  placement: PlacementSpec(strategy: 'rings'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [SizeOption(id: 'l', name: 'L')],
  optionGroups: [],
  animation: [StepSpec(step: 'Oven')],
  assetSpecs: {},
);

PricingData data({int base = 10000}) => PricingData(
  definitions: const {'c': def},
  products: {
    'p': Product(
      id: 'p',
      categoryId: 'c',
      name: 'p',
      description: '',
      basePrice: base,
      imageAssetId: 'i',
      isAvailable: true,
      defaults: const [
        ProductIngredient(ingredientId: 'cheese', qty: 1, removable: true),
        ProductIngredient(ingredientId: 'olive', qty: 1, removable: true),
      ],
    ),
  },
  ingredients: {
    for (final id in ['cheese', 'olive', 'pepper'])
      id: Ingredient(
        id: id,
        name: id,
        assetId: 'a',
        extraPrice: 750,
        isAvailable: true,
      ),
  },
);

void main() {
  // The fixture order: cheese 2 (1 extra) + pepper 1, olive removed,
  // snapshot total 11500 = 10000 + 750 + 750.
  test('a correctly priced order matches', () {
    final v = verifyOrder(order('o', OrderStatus.newOrder), data());
    expect(v.matches, isTrue);
    expect(v.computedTotal, 11500);
  });

  test('a tampered or outdated price is flagged with the computed total', () {
    final v = verifyOrder(order('o', OrderStatus.newOrder), data(base: 12000));
    expect(v.matches, isFalse);
    expect(v.computedTotal, 13500);
  });

  test('transitions follow the lifecycle; delivery adds out-for-delivery', () {
    expect(nextStatuses(order('o', OrderStatus.newOrder)), [
      OrderStatus.accepted,
      OrderStatus.cancelled,
    ]);
    expect(nextStatuses(order('o', OrderStatus.preparing)), [
      OrderStatus.ready,
    ]);
    expect(nextStatuses(order('o', OrderStatus.ready)), [
      OrderStatus.outForDelivery,
    ], reason: 'fixture is a delivery order');
    expect(nextStatuses(order('o', OrderStatus.completed)), isEmpty);
    expect(nextPaymentStatuses(PaymentStatus.unpaid), [
      PaymentStatus.paid,
      PaymentStatus.refunded,
    ]);
  });
}
