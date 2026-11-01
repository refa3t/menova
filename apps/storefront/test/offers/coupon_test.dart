import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/cart/domain/cart.dart';
import 'package:storefront/features/offers/data/offers_repository.dart';
import 'package:storefront/features/offers/domain/cart_offer.dart';
import 'package:storefront/features/offers/presentation/offers_providers.dart';

import '../cart/cart_test.dart' show sel;
import '../checkout/order_scenarios_test.dart' show menuWith;

/// Coupons by code, without a server.
class FakeOffers implements OffersRepository {
  final asked = <String>[];
  bool offline = false;

  @override
  Future<Offer?> coupon(String code, {bool fromServer = false}) async {
    asked.add(code);
    if (offline) throw Exception('offline');
    return code == 'SAVE20'
        ? const Offer(
            id: 'SAVE20',
            name: 'TEMP',
            kind: OfferKind.amount,
            value: 2000,
            code: 'SAVE20',
          )
        : null;
  }

  @override
  Stream<List<Offer>> watchActive() => Stream.value(const []);

  @override
  Future<List<Offer>> activeFromServer() async => const [];
}

void main() {
  test('a typed coupon is looked up by its one stored form', () async {
    final repo = FakeOffers();
    final c = ProviderContainer(
      overrides: [offersRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    final coupon = c.read(couponProvider.notifier);

    await coupon.apply(' save 20 ');
    expect(couponOf(c.read(couponProvider))?.code, 'SAVE20');

    await coupon.apply('x');
    expect(c.read(couponProvider), isA<CouponNotFound>());
    expect(repo.asked, ['SAVE20'], reason: 'no lookup for an impossible code');

    await coupon.apply('NOPE1');
    expect(c.read(couponProvider), isA<CouponNotFound>());

    repo.offline = true;
    await coupon.apply('SAVE20');
    expect(c.read(couponProvider), isA<CouponFailed>());

    coupon.clear();
    expect(c.read(couponProvider), isA<NoCoupon>());
  });

  test('the cart brings its lines by category to an offer', () {
    final cart = Cart.empty.add(
      CartLine(lineId: 'l1', selection: sel({'cheese': 2, 'olive': 1}), qty: 1),
    );
    final basis = cartBasis(
      cart,
      menuWith(),
      deliveryFee: 3000,
      now: DateTime(2026, 11, 1),
    );
    expect(basis.itemsByCategory, {'cat': 11500});
    expect(basis.deliveryFee, 3000);
    expect(basis.atMs, DateTime(2026, 11, 1).millisecondsSinceEpoch);
  });
}
