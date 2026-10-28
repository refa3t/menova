// P1-H07: trial events carry no personal data, and a retried order is
// counted once.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/core/analytics/analytics.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/checkout/presentation/checkout_controller.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';

import '../cart/cart_test.dart' show sel;
import 'order_scenarios_test.dart' show FakeGateway, guest, menuWith;

class RecordingAnalytics implements Analytics {
  final events = <(String, Map<String, Object>)>[];

  @override
  void event(String name, [Map<String, Object> params = const {}]) =>
      events.add((name, params));
}

void main() {
  test('a retried order is counted once, without personal data', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final gateway = FakeGateway();
    final analytics = RecordingAnalytics();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        menuProvider.overrideWith((ref) async => menuWith()),
        freshMenuProvider.overrideWithValue(() async => menuWith()),
        guestUidProvider.overrideWithValue(() async => 'guest-1'),
        orderGatewayProvider.overrideWithValue(gateway),
        analyticsProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(c.dispose);
    c.listen(checkoutProvider, (_, _) {});
    await c.read(menuProvider.future);
    c.read(cartProvider.notifier).add(sel({'cheese': 2}));

    // The reply is lost, then the guest retries with the same request.
    gateway.loseNextReply = true;
    await c.read(checkoutProvider.notifier).confirm(customer: guest, notes: '');
    await c.read(checkoutProvider.notifier).confirm(customer: guest, notes: '');

    expect(gateway.orders, hasLength(1));
    final logged = analytics.events.where((e) => e.$1 == 'purchase').toList();
    expect(logged, hasLength(1), reason: 'the retried order counts once');
    expect(logged.single.$2['transaction_id'], gateway.orders.keys.single);
    final params = logged.single.$2;
    expect(params['currency'], 'EGP');
    expect(params.keys, isNot(contains('phone')));
    expect(params.values, isNot(contains(guest.name)));
    expect(params.values, isNot(contains(guest.phone)));
  });
}
