import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricing/pricing.dart';

import '../../cart/presentation/cart_providers.dart';
import '../../delivery/presentation/delivery_controller.dart';
import '../../menu/domain/menu.dart';
import '../../menu/presentation/menu_providers.dart';
import '../data/order_submitter.dart';
import '../domain/order_builder.dart';

/// Checkout states (CLAUDE.md 5.2 and its UI states).
sealed class CheckoutState {
  const CheckoutState();
}

class CheckoutIdle extends CheckoutState {
  const CheckoutIdle();
}

/// Sending; the confirm button is locked (scenario 6).
class CheckoutSending extends CheckoutState {
  const CheckoutSending({required this.checking});

  /// True when re-asking about an earlier, unconfirmed attempt.
  final bool checking;
}

/// "بانتظار الإرسال": not confirmed; retry reuses the same request id.
class CheckoutPending extends CheckoutState {
  const CheckoutPending();
}

/// Prices or availability changed (scenarios 4 and 9).
class CheckoutPriceChanged extends CheckoutState {
  const CheckoutPriceChanged(this.diffs);
  final List<PriceDiff> diffs;
}

class CheckoutConflict extends CheckoutState {
  const CheckoutConflict();
}

class CheckoutDone extends CheckoutState {
  const CheckoutDone(this.orderId);
  final String orderId;
}

/// Who the guest is (Anonymous Auth). Overridable in tests.
final guestUidProvider = Provider<Future<String> Function()>(
  (ref) => () async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser ?? (await auth.signInAnonymously()).user;
    return user!.uid;
  },
);

final orderGatewayProvider = Provider<OrderGateway>(
  (ref) => OrderSubmitter(FirebaseFirestore.instance),
);

/// Fresh menu straight from the server (never the cache) for re-pricing.
final freshMenuProvider = Provider<Future<Menu> Function()>(
  (ref) =>
      () => ref.read(menuRepositoryProvider).load(fromServer: true),
);

final checkoutProvider =
    NotifierProvider.autoDispose<CheckoutController, CheckoutState>(
      CheckoutController.new,
    );

class CheckoutController extends Notifier<CheckoutState> {
  static const _requestKey = 'pendingRequest.v1';
  final _random = Random.secure();

  @override
  CheckoutState build() => const CheckoutIdle();

  /// Line id of the delivery fee in a [PriceDiff].
  static const deliveryLineId = 'delivery';

  /// [shownDeliveryFee] is the fee the guest saw; it is re-priced from
  /// fresh store settings before sending, like the items.
  Future<void> confirm({
    required GuestCustomer customer,
    required String notes,
    int shownDeliveryFee = 0,
  }) async {
    if (state is CheckoutSending) return; // One send at a time (scenario 6).
    final checking = state is CheckoutPending;
    state = CheckoutSending(checking: checking);

    // Scenario 2/7: an earlier attempt may have been created and its reply
    // lost. Ask first; if it exists, it stands at its frozen prices.
    final pending = _savedRequest();
    if (checking && pending != null) {
      try {
        final hash = await ref.read(orderGatewayProvider).find(pending.id);
        if (hash != null && hash == pending.hash) {
          _complete(pending.id);
          return;
        }
      } on Object {
        state = const CheckoutPending();
        return;
      }
    }

    final cart = ref.read(cartProvider);
    final shown = ref.read(menuProvider).value;
    final Menu fresh;
    final String uid;
    StoreSettings? settings;
    try {
      uid = await ref.read(guestUidProvider)();
      fresh = await ref.read(freshMenuProvider)();
      if (customer.fulfillment == Fulfillment.delivery) {
        settings = await ref.read(storeSettingsLoaderProvider)();
      }
    } on Object catch (e) {
      debugPrint('checkout: before send failed: $e');
      state = const CheckoutPending(); // Offline before reaching the server.
      return;
    }

    // Scenario 4: never confirm an order at an old price.
    final diffs = shown == null
        ? <PriceDiff>[]
        : OrderBuilder.diff(cart, shown, fresh);
    var fee = 0;
    if (settings != null) {
      int? current;
      try {
        current = deliveryFee(customer.distanceMeters ?? -1, settings.delivery);
      } on PricingException {
        current = null;
      }
      if (current != shownDeliveryFee) {
        diffs.add(
          PriceDiff(
            lineId: deliveryLineId,
            productName: deliveryLineId,
            shown: shownDeliveryFee,
            current: current,
          ),
        );
      }
      fee = current ?? 0;
    }
    if (diffs.isNotEmpty) {
      state = CheckoutPriceChanged(diffs);
      return;
    }

    final List<OrderItem> items;
    try {
      items = OrderBuilder.items(cart, fresh);
    } on OrderBuildException {
      state = CheckoutPriceChanged(OrderBuilder.diff(cart, fresh, fresh));
      return;
    }
    final hash = OrderBuilder.payloadHash(
      items: items,
      customer: customer,
      notes: notes,
    );
    final requestId = _requestIdFor(hash);
    final order = OrderBuilder.build(
      requestId: requestId,
      customerUid: uid,
      items: items,
      customer: customer,
      notes: notes,
      now: DateTime.now(),
      deliveryFee: fee,
    );

    final result = await ref.read(orderGatewayProvider).submit(order);
    switch (result) {
      case Submitted(:final orderId):
        _complete(orderId);
      case NotConfirmed():
        state = const CheckoutPending();
      case Conflict():
        _clearRequest(); // The next attempt gets a fresh id.
        state = const CheckoutConflict();
    }
  }

  /// The customer accepted the corrected prices: refresh the shown menu so
  /// the cart shows them; the next confirm uses a new request id because
  /// the content (prices) changed.
  void acceptCorrections() {
    ref.invalidate(menuProvider);
    ref.read(deliveryProvider.notifier).reprice();
    state = const CheckoutIdle();
  }

  void dismiss() => state = const CheckoutIdle();

  void _complete(String orderId) {
    _clearRequest();
    ref.read(cartProvider.notifier).clear();
    state = CheckoutDone(orderId);
  }

  ({String id, String hash})? _savedRequest() {
    final raw = ref.read(sharedPreferencesProvider).getString(_requestKey);
    if (raw == null) return null;
    try {
      final saved = jsonDecode(raw) as Map<String, dynamic>;
      return (id: saved['requestId'] as String, hash: saved['hash'] as String);
    } on Object {
      return null;
    }
  }

  /// One request id per cart content, kept on the device so a re-confirm
  /// after a lost reply finds the existing order instead of a duplicate.
  String _requestIdFor(String hash) {
    final prefs = ref.read(sharedPreferencesProvider);
    final raw = prefs.getString(_requestKey);
    if (raw != null) {
      try {
        final saved = jsonDecode(raw) as Map<String, dynamic>;
        if (saved['hash'] == hash) return saved['requestId'] as String;
      } on Object {
        // Corrupt entry: replace it.
      }
    }
    final id = List.generate(
      20,
      (_) => 'abcdefghijklmnopqrstuvwxyz0123456789'[_random.nextInt(36)],
    ).join();
    prefs.setString(_requestKey, jsonEncode({'hash': hash, 'requestId': id}));
    return id;
  }

  void _clearRequest() =>
      ref.read(sharedPreferencesProvider).remove(_requestKey);
}
