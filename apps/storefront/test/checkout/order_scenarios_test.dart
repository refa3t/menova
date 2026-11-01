// P1-E10: the nine order scenarios of CLAUDE.md 5.2 (D-INFRA-01 = B).
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/checkout/data/order_submitter.dart';
import 'package:storefront/features/checkout/presentation/checkout_controller.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';
import 'package:storefront/features/offers/domain/cart_offer.dart';

import '../cart/cart_test.dart' show def, product, sel;

/// In-memory server with the transaction semantics of OrderSubmitter.
class FakeGateway implements OrderGateway {
  final orders = <String, Order>{};
  int submits = 0;

  /// Next submit: store it but lose the reply (scenario 2).
  bool loseNextReply = false;

  /// Next submit: fail before reaching the server (scenario 3).
  bool failNextBeforeServer = false;

  /// Next submit: the order's coupon ran out in the meantime (P3-09).
  bool couponGoneNext = false;

  @override
  Future<SubmitResult> submit(Order order) async {
    submits++;
    if (failNextBeforeServer) {
      failNextBeforeServer = false;
      return const NotConfirmed();
    }
    if (couponGoneNext && order.offer?.code != null) {
      couponGoneNext = false;
      return const OfferUnavailable();
    }
    final decision = decideExisting(
      existingHash: orders[order.requestId]?.payloadHash,
      order: order,
    );
    if (decision case Submitted(alreadyExisted: false)) {
      orders[order.requestId] = order;
    }
    if (loseNextReply) {
      loseNextReply = false;
      return const NotConfirmed();
    }
    return decision;
  }

  @override
  Future<String?> find(String requestId) async =>
      orders[requestId]?.payloadHash;
}

// TEMP fixtures, not owner data.
Menu menuWith({int cheesePrice = 1500, bool pepperAvailable = true}) =>
    Menu.assemble(
      definitions: {'cat': def},
      contents: const [
        CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
      ],
      products: const [product],
      ingredients: [
        Ingredient(
          id: 'cheese',
          name: 'جبنة',
          assetId: 'a',
          extraPrice: cheesePrice,
          isAvailable: true,
        ),
        const Ingredient(
          id: 'olive',
          name: 'زيتون',
          assetId: 'a',
          extraPrice: 1000,
          isAvailable: true,
        ),
        Ingredient(
          id: 'pepper',
          name: 'فلفل',
          assetId: 'a',
          extraPrice: 1500,
          isAvailable: pepperAvailable,
        ),
      ],
      assets: const [],
    );

const guest = GuestCustomer(
  name: 'TEMP',
  phone: '01012345678',
  fulfillment: Fulfillment.pickup,
);

class Harness {
  Harness(this.prefs);

  final SharedPreferences prefs;
  final gateway = FakeGateway();
  Menu shown = menuWith();
  Menu fresh = menuWith();

  /// Live offers and the guest's coupon on the server (P3-09).
  List<Offer> offers = const [];
  late final ProviderContainer c = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      menuProvider.overrideWith((ref) async => shown),
      freshMenuProvider.overrideWithValue(() async => fresh),
      freshOffersProvider.overrideWithValue(() async => offers),
      guestUidProvider.overrideWithValue(() async => 'guest-1'),
      orderGatewayProvider.overrideWithValue(gateway),
    ],
  );

  CheckoutController get checkout => c.read(checkoutProvider.notifier);
  CheckoutState get state => c.read(checkoutProvider);

  Future<void> start() async {
    c.listen(checkoutProvider, (_, _) {}); // Keep the autoDispose alive.
    await c.read(menuProvider.future);
    c.read(cartProvider.notifier).add(sel({'cheese': 2, 'olive': 1}));
  }

  Future<void> confirm({AppliedOffer? shownOffer}) =>
      checkout.confirm(customer: guest, notes: '', shownOffer: shownOffer);
}

void main() {
  late Harness h;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    h = Harness(await SharedPreferences.getInstance());
    await h.start();
  });
  tearDown(() => h.c.dispose());

  test('1. normal send creates one order with frozen prices', () async {
    await h.confirm();
    expect(h.state, isA<CheckoutDone>());
    expect(h.gateway.orders, hasLength(1));
    final order = h.gateway.orders.values.single;
    expect(order.total, 10000 + 1500, reason: 'base + one extra cheese');
    expect(order.items.single.defaultQty, {'cheese': 1, 'olive': 1});
    expect(order.status, OrderStatus.newOrder);
    expect(h.c.read(cartProvider).lines, isEmpty);
  });

  test(
    '2. order created but reply lost: retry returns it, no duplicate',
    () async {
      h.gateway.loseNextReply = true;
      await h.confirm();
      expect(h.state, isA<CheckoutPending>());
      await h.confirm();
      expect(h.state, isA<CheckoutDone>());
      expect(h.gateway.orders, hasLength(1));
    },
  );

  test(
    '3. failed before reaching the server: retry creates exactly one',
    () async {
      h.gateway.failNextBeforeServer = true;
      await h.confirm();
      expect(h.state, isA<CheckoutPending>());
      expect(h.gateway.orders, isEmpty);
      await h.confirm();
      expect(h.state, isA<CheckoutDone>());
      expect(h.gateway.orders, hasLength(1));
    },
  );

  test(
    '4. price changed: refused with diffs, then sent with a new id',
    () async {
      h.fresh = menuWith(cheesePrice: 2000);
      await h.confirm();
      final changed = h.state as CheckoutPriceChanged;
      expect(changed.diffs.single.shown, 11500);
      expect(changed.diffs.single.current, 12000);
      expect(h.gateway.submits, 0, reason: 'never confirmed at an old price');

      h.shown = h.fresh;
      h.checkout.acceptCorrections();
      await h.c.read(menuProvider.future);
      await h.confirm();
      expect(h.state, isA<CheckoutDone>());
      expect(h.gateway.orders.values.single.total, 12000);
    },
  );

  test('4b. an item that ran out is reported, nothing is sent', () async {
    h.c
        .read(cartProvider.notifier)
        .add(sel({'cheese': 1, 'olive': 1, 'pepper': 1}));
    h.fresh = menuWith(pepperAvailable: false);
    await h.confirm();
    final changed = h.state as CheckoutPriceChanged;
    expect(changed.diffs.any((d) => d.current == null), isTrue);
    expect(h.gateway.submits, 0);
  });

  test('5. same id with different content is a conflict', () async {
    h.gateway.loseNextReply = true;
    await h.confirm(); // Stored under a saved request id.
    final savedId = h.gateway.orders.keys.single;
    // Different content now maps to the same saved id (corrupt state).
    h.gateway.orders[savedId] = Order.fromJson({
      ...h.gateway.orders[savedId]!.toJson(),
      'payloadHash': 'f' * 64,
    });
    h.checkout.dismiss();
    await h.confirm();
    expect(h.state, isA<CheckoutConflict>());
    expect(h.gateway.orders, hasLength(1));
  });

  test('6. repeated confirm taps send once', () async {
    await Future.wait([h.confirm(), h.confirm(), h.confirm()]);
    expect(h.gateway.submits, 1);
    expect(h.gateway.orders, hasLength(1));
  });

  test('7. price changes after creation, before the retry: existing order '
      'stands at its frozen prices', () async {
    h.gateway.loseNextReply = true;
    await h.confirm();
    expect(h.state, isA<CheckoutPending>());
    h.fresh = menuWith(cheesePrice: 9999);
    await h.confirm();
    expect(h.state, isA<CheckoutDone>());
    expect(h.gateway.orders.values.single.total, 11500);
  });

  test(
    '8. an ingredient running out after creation does not touch the order',
    () async {
      await h.confirm();
      final before = h.gateway.orders.values.single.toJson();
      h.fresh = menuWith(pepperAvailable: false);
      expect(h.gateway.orders.values.single.toJson(), before);
    },
  );

  test('9. price changes again after accepting: correction repeats', () async {
    h.fresh = menuWith(cheesePrice: 2000);
    await h.confirm();
    expect(h.state, isA<CheckoutPriceChanged>());
    h.shown = h.fresh;
    h.checkout.acceptCorrections();
    await h.c.read(menuProvider.future);
    h.fresh = menuWith(cheesePrice: 2500);
    await h.confirm();
    expect(h.state, isA<CheckoutPriceChanged>());
    expect(h.gateway.submits, 0);
  });

  group('offers (P3-09)', () {
    const tenPercent = Offer(
      id: 'o1',
      name: 'TEMP 10%',
      kind: OfferKind.percent,
      value: 10,
    );
    const coupon = Offer(
      id: 'SAVE20',
      name: 'TEMP coupon',
      kind: OfferKind.amount,
      value: 2000,
      code: 'SAVE20',
      maxUses: 5,
    );

    test('the offer shown is frozen with the order', () async {
      h.offers = [tenPercent];
      // 10% of 115 EGP is 11.5, rounded once to 12.
      await h.confirm(shownOffer: (offer: tenPercent, discount: 1200));
      expect(h.state, isA<CheckoutDone>());
      final order = h.gateway.orders.values.single;
      expect(order.discount, 1200);
      expect(order.total, 11500 - 1200);
      expect(order.offer, OrderOffer.of(tenPercent));
    });

    test('an offer that ended is shown before anything is sent', () async {
      h.offers = const [];
      await h.confirm(shownOffer: (offer: tenPercent, discount: 1200));
      final state = h.state as CheckoutPriceChanged;
      final diff = state.diffs.single;
      expect(diff.lineId, CheckoutController.discountLineId);
      expect((diff.shown, diff.current), (1200, 0));
      expect(h.gateway.submits, 0);
    });

    test('a bigger coupon wins over the automatic offer', () async {
      h.offers = [tenPercent, coupon];
      await h.confirm(shownOffer: (offer: coupon, discount: 2000));
      expect(h.state, isA<CheckoutDone>());
      expect(h.gateway.orders.values.single.offer?.code, 'SAVE20');
    });

    test('a coupon that ran out while sending writes nothing', () async {
      h.offers = [coupon];
      h.gateway.couponGoneNext = true;
      await h.confirm(shownOffer: (offer: coupon, discount: 2000));
      final state = h.state as CheckoutPriceChanged;
      expect((state.diffs.single.shown, state.diffs.single.current), (2000, 0));
      expect(h.gateway.orders, isEmpty);
    });
  });
}
