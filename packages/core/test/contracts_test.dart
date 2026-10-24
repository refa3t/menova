import 'dart:convert';

import 'package:core/core.dart';
import 'package:test/test.dart';

Map<String, dynamic> viaString(Map<String, dynamic> j) =>
    jsonDecode(jsonEncode(j)) as Map<String, dynamic>;

// TEMP fixtures, not owner data.
const defaults = [
  ProductIngredient(ingredientId: 'cheese', qty: 2, removable: false),
  ProductIngredient(ingredientId: 'olive', qty: 1, removable: true),
];

const selection = Selection(
  productId: 'p1',
  categoryId: 'cat_a',
  definitionVersion: 1,
  sizeId: 'm',
  options: {'grp': 'c2'},
  ingredients: {'cheese': 3, 'olive': 0, 'pepper': 1},
  notes: 'TEMP note',
);

const price = PriceBreakdown(
  lines: [
    PriceLine(kind: PriceLineKind.base, amount: 10000),
    PriceLine(kind: PriceLineKind.extra, refId: 'cheese', qty: 1, amount: 1500),
    PriceLine(kind: PriceLineKind.refund, refId: 'olive', amount: -500),
  ],
  unitSubtotal: 11000,
  itemQty: 2,
  rounding: 0,
  total: 22000,
  ruleVersion: 1,
);

const item = OrderItem(
  lineId: 'l1',
  selection: selection,
  price: price,
  productName: 'TEMP product',
  sizeName: 'TEMP M',
  optionNames: {'c2': 'TEMP c2'},
  ingredientNames: {'cheese': 'TEMP cheese', 'olive': 'TEMP olive'},
);

void main() {
  test('Selection round-trips and ignores zero quantities', () {
    expect(Selection.fromJson(viaString(selection.toJson())), selection);
    expect(selection.toJson()['ingredients'], {'cheese': 3, 'pepper': 1});
  });

  test('Selection derives extras and removed from defaults', () {
    expect(selection.extras(defaults), {'cheese': 1, 'pepper': 1});
    expect(selection.removed(defaults), ['olive']);
  });

  test('Selection.initial is the untouched product', () {
    const p = Product(
      id: 'p1',
      categoryId: 'cat_a',
      name: 'n',
      description: '',
      basePrice: 1,
      imageAssetId: 'i',
      defaults: defaults,
      isAvailable: true,
    );
    final s = Selection.initial(p, definitionVersion: 3);
    expect(s.extras(defaults), isEmpty);
    expect(s.removed(defaults), isEmpty);
    expect(s.definitionVersion, 3);
  });

  test('PriceBreakdown, RenderSnapshot, StepSequence round-trip', () {
    expect(PriceBreakdown.fromJson(viaString(price.toJson())), price);
    const snap = RenderSnapshot(
      baseAssetId: 'base',
      cookedBaseAssetId: 'base_cooked',
      scale: 0.9,
      layers: [
        RenderLayer(
          ingredientId: 'cheese',
          assetId: 'a',
          qty: 3,
          layerOrder: 10,
        ),
      ],
    );
    expect(RenderSnapshot.fromJson(viaString(snap.toJson())), snap);
    const seq = StepSequence([
      StepSpec(step: 'A', weight: 3),
      StepSpec(step: 'B', weight: 1),
    ]);
    expect(StepSequence.fromJson(viaString(seq.toJson())), seq);
    expect(seq.shares, [0.75, 0.25]);
  });

  test('OrderItem and Order round-trip with frozen snapshots', () {
    expect(OrderItem.fromJson(viaString(item.toJson())), item);
    const order = Order(
      id: 'r1',
      requestId: 'r1',
      payloadHash: 'h',
      customerUid: 'u1',
      customer: GuestCustomer(
        name: 'TEMP',
        phone: '000',
        fulfillment: Fulfillment.delivery,
        address: 'TEMP',
      ),
      items: [item],
      status: OrderStatus.outForDelivery,
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: PaymentMethod.cash,
      deliveryFee: 0,
      total: 22000,
      definitionVersions: {'cat_a': 1},
      rulesVersion: 1,
      createdAt: '2026-01-01T00:00:00Z',
      history: [
        StatusChange(field: 'status', value: 'accepted', by: 's1', at: 't'),
      ],
    );
    final back = Order.fromJson(viaString(order.toJson()));
    expect(back, order);
    expect(order.toJson()['status'], 'out_for_delivery');
  });

  test('unknown enum values are rejected', () {
    expect(() => OrderStatus.fromWire('lost'), throwsFormatException);
  });
}
