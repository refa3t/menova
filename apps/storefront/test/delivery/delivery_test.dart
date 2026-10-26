// Delivery priced by road distance (owner decision P0-05).
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/checkout/presentation/checkout_controller.dart';
import 'package:storefront/features/delivery/data/geo_locator.dart';
import 'package:storefront/features/delivery/data/route_service.dart';
import 'package:storefront/features/delivery/domain/delivery_quote.dart';
import 'package:storefront/features/delivery/presentation/delivery_controller.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';

import '../cart/cart_test.dart' show sel;
import '../checkout/order_scenarios_test.dart' show FakeGateway, menuWith;

class FakeLocator implements GeoLocator {
  Object? error;
  LatLng here = const LatLng(30.46, 31.18);

  @override
  Future<LatLng> current() async {
    if (error != null) throw error!;
    return here;
  }
}

class FakeRoute implements RouteService {
  int meters = 4300;
  bool fail = false;

  @override
  Future<int> roadMeters(LatLng from, LatLng to) async {
    if (fail) throw StateError('offline');
    return meters;
  }
}

// TEMP fixture shaped like settings/store.
StoreSettings settingsWith({int perKm = 600}) => StoreSettings(
  location: const LatLng(30.4468569, 31.1910437),
  delivery: DeliverySettings(
    perKm: perKm,
    minFee: 2500,
    maxDistanceMeters: 15000,
  ),
);

void main() {
  late SharedPreferences prefs;
  late FakeLocator locator;
  late FakeRoute route;
  late FakeGateway gateway;
  late StoreSettings settings;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    locator = FakeLocator();
    route = FakeRoute();
    gateway = FakeGateway();
    settings = settingsWith();
    c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        menuProvider.overrideWith((ref) async => menuWith()),
        freshMenuProvider.overrideWithValue(() async => menuWith()),
        guestUidProvider.overrideWithValue(() async => 'guest-1'),
        orderGatewayProvider.overrideWithValue(gateway),
        geoLocatorProvider.overrideWithValue(locator),
        routeServiceProvider.overrideWithValue(route),
        storeSettingsLoaderProvider.overrideWithValue(() async => settings),
      ],
    );
    c.listen(deliveryProvider, (_, _) {});
    c.listen(checkoutProvider, (_, _) {});
    addTearDown(c.dispose);
  });

  DeliveryState state() => c.read(deliveryProvider);

  test('location and road distance give the fee (started km)', () async {
    await c.read(deliveryProvider.notifier).locate();
    final quote = (state() as DeliveryQuoted).quote;
    expect(quote.distanceMeters, 4300);
    expect(quote.fee, 3000); // 5 km × 6 EGP
    expect(quote.location, locator.here);
  });

  test('denied permission, route failure and out of range are reported', () async {
    locator.error = const LocationDenied();
    await c.read(deliveryProvider.notifier).locate();
    expect((state() as DeliveryFailed).error, DeliveryError.denied);

    locator.error = null;
    route.fail = true;
    await c.read(deliveryProvider.notifier).locate();
    expect((state() as DeliveryFailed).error, DeliveryError.routeFailed);

    route
      ..fail = false
      ..meters = 15001;
    await c.read(deliveryProvider.notifier).locate();
    expect((state() as DeliveryFailed).error, DeliveryError.outOfRange);
  });

  Future<GuestCustomer> quotedGuest() async {
    await c.read(menuProvider.future);
    c.read(cartProvider.notifier).add(sel({'cheese': 2}));
    await c.read(deliveryProvider.notifier).locate();
    final quote = (state() as DeliveryQuoted).quote;
    return GuestCustomer(
      name: 'TEMP',
      phone: '01012345678',
      fulfillment: Fulfillment.delivery,
      address: 'TEMP street 1',
      location: quote.location,
      distanceMeters: quote.distanceMeters,
    );
  }

  test('the order carries the location, distance and fee', () async {
    final guest = await quotedGuest();
    await c
        .read(checkoutProvider.notifier)
        .confirm(customer: guest, notes: '', shownDeliveryFee: 3000);
    expect(c.read(checkoutProvider), isA<CheckoutDone>());
    final order = gateway.orders.values.single;
    expect(order.deliveryFee, 3000);
    expect(
      order.total,
      order.items.fold<int>(0, (s, i) => s + i.price.total) + 3000,
    );
    expect(order.customer.distanceMeters, 4300);
    expect(order.customer.location, locator.here);
  });

  test('a changed delivery rate is shown before sending, then re-priced', () async {
    final guest = await quotedGuest();
    settings = settingsWith(perKm: 700); // Admin changed the rate.
    await c
        .read(checkoutProvider.notifier)
        .confirm(customer: guest, notes: '', shownDeliveryFee: 3000);
    final changed = c.read(checkoutProvider) as CheckoutPriceChanged;
    final d = changed.diffs.single;
    expect(d.lineId, CheckoutController.deliveryLineId);
    expect((d.shown, d.current), (3000, 3500));
    expect(gateway.orders, isEmpty);

    c.read(checkoutProvider.notifier).acceptCorrections();
    await Future<void>.delayed(Duration.zero);
    expect((state() as DeliveryQuoted).quote.fee, 3500);
  });
}
