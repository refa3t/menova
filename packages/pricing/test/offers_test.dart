// Runs the offer vectors (test_vectors/offers.json, P3-09) and checks how
// the one offer of an order is chosen.
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:pricing/pricing.dart';
import 'package:test/test.dart';

void main() {
  final v =
      jsonDecode(File('../../test_vectors/offers.json').readAsStringSync())
          as Map<String, dynamic>;

  test('vector rules match the engine rules', () {
    expect(v['rules']['roundingStep'], PricingRules.current.roundingStep);
  });

  for (final c in (v['cases'] as List).cast<Map<String, dynamic>>()) {
    test(c['name'], () {
      final offer = Offer.fromJson({
        'id': 'o1',
        'name': 'offer',
        ...c['offer'] as Map<String, dynamic>,
      });
      final o = c['order'] as Map<String, dynamic>;
      final basis = OfferBasis(
        itemsByCategory: (o['items'] as Map<String, dynamic>).cast(),
        deliveryFee: o['deliveryFee'] as int? ?? 0,
        atMs: o['atMs'] as int,
      );
      final r = offerDiscount(offer, basis);
      final expected = c['expect'] as Map<String, dynamic>;
      expect(r.miss?.name, expected['miss']);
      expect(r.discount, expected['discount'] ?? 0);
    });
  }

  group('best offer', () {
    const basis = OfferBasis(
      itemsByCategory: {'cat_a': 20000},
      deliveryFee: 3000,
      atMs: 1000,
    );
    const tenPercent = Offer(
      id: 'auto_b',
      name: '10%',
      kind: OfferKind.percent,
      value: 10,
    );
    const freeDelivery = Offer(
      id: 'auto_a',
      name: 'free delivery',
      kind: OfferKind.freeDelivery,
    );

    test('the largest discount wins (one offer per order)', () {
      final best = bestOffer([tenPercent, freeDelivery], basis)!;
      expect(best.offer, freeDelivery);
      expect(best.discount, 3000);
    });

    test('on a tie the automatic offer is kept and the coupon unused', () {
      const coupon = Offer(
        id: 'SAVE20',
        name: 'coupon',
        kind: OfferKind.amount,
        value: 2000,
        code: 'SAVE20',
      );
      final best = bestOffer([coupon, tenPercent], basis)!;
      expect(best.offer, tenPercent);
      expect(best.discount, 2000);
    });

    test('nothing when no offer applies', () {
      const later = Offer(
        id: 'x',
        name: 'later',
        kind: OfferKind.amount,
        value: 1000,
        startsAtMs: 5000,
      );
      expect(bestOffer([later], basis), isNull);
      expect(bestOffer(const [], basis), isNull);
    });
  });

  test('an order basis sums the items by category', () {
    OrderItem item(String category, int total) => OrderItem(
      lineId: 'l$total',
      selection: Selection(
        productId: 'p',
        categoryId: category,
        definitionVersion: 1,
      ),
      price: PriceBreakdown(
        lines: const [],
        unitSubtotal: total,
        itemQty: 1,
        rounding: 0,
        total: total,
        ruleVersion: 2,
      ),
      productName: 'p',
    );
    final b = OfferBasis.of(
      [item('cat_a', 1000), item('cat_b', 500), item('cat_a', 250)],
      deliveryFee: 2500,
      atMs: 7,
    );
    expect(b.itemsByCategory, {'cat_a': 1250, 'cat_b': 500});
    expect(b.itemsTotal, 1750);
    expect(b.deliveryFee, 2500);
  });
}
