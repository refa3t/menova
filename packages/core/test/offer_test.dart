import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  const coupon = Offer(
    id: 'WELCOME',
    name: 'خصم الترحيب',
    names: {'en': 'Welcome'},
    kind: OfferKind.percent,
    value: 10,
    categoryId: 'cat_a',
    minSubtotal: 20000,
    maxDiscount: 5000,
    startsAtMs: 1000,
    endsAtMs: 2000,
    code: 'WELCOME',
    maxUses: 50,
    uses: 3,
  );

  test('an offer round-trips through JSON with every key written', () {
    final j = coupon.toJson();
    expect(Offer.fromJson(j), coupon);
    const auto = Offer(
      id: 'a1',
      name: 'توصيل مجاني',
      kind: OfferKind.freeDelivery,
    );
    // Null fields are still written: the Firestore rules compare them.
    expect(auto.toJson().keys, containsAll(['categoryId', 'code', 'maxUses']));
    expect(auto.toJson()['code'], isNull);
    expect(Offer.fromJson(auto.toJson()), auto);
    expect(auto.isCoupon, isFalse);
    expect(coupon.isCoupon, isTrue);
    expect(coupon.nameFor('en'), 'Welcome');
    expect(coupon.nameFor('ar'), 'خصم الترحيب');
  });

  test('a typed coupon code takes one stored form', () {
    expect(couponCode(' welcome '), 'WELCOME');
    expect(couponCode('save ٢٠'), 'SAVE20');
    expect(couponCode('eid-26'), 'EID-26');
    expect(couponCode('ab'), isNull); // too short
    expect(couponCode('كود'), isNull); // Latin letters only
    expect(couponCode('a/b/c'), isNull); // never a path
  });

  test('an order keeps its offer frozen, and old orders still read', () {
    final snapshot = OrderOffer.of(coupon);
    expect(snapshot.asOffer.kind, coupon.kind);
    expect(snapshot.asOffer.maxDiscount, 5000);
    expect(snapshot.asOffer.isActive, isTrue); // no dates or uses: as ordered
    expect(snapshot.asOffer.startsAtMs, isNull);
    expect(OrderOffer.fromJson(snapshot.toJson()), snapshot);

    final order = Order(
      id: 'r1',
      requestId: 'r1',
      payloadHash: 'h',
      customerUid: 'u',
      customer: const GuestCustomer(
        name: 'Test',
        phone: '01000000000',
        fulfillment: Fulfillment.pickup,
      ),
      items: const [],
      status: OrderStatus.newOrder,
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: PaymentMethod.cash,
      deliveryFee: 0,
      total: 0,
      definitionVersions: const {},
      rulesVersion: 2,
      createdAt: '2026-11-01T10:00:00Z',
      discount: 2000,
      offer: snapshot,
    );
    expect(Order.fromJson(order.toJson()), order);

    // Without an offer the order keeps its earlier shape.
    final plain = Order.fromJson(
      order.toJson()
        ..remove('discount')
        ..remove('offer'),
    );
    expect(plain.discount, 0);
    expect(plain.offer, isNull);
    expect(plain.toJson().containsKey('offer'), isFalse);
  });
}
