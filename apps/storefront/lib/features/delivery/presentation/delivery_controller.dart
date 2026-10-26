import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricing/pricing.dart';

import '../data/geo_locator.dart';
import '../data/route_service.dart';
import '../data/store_settings_repository.dart';
import '../domain/delivery_quote.dart';

final geoLocatorProvider = Provider<GeoLocator>((ref) => platformGeoLocator());

final routeServiceProvider = Provider<RouteService>(
  (ref) => OsrmRouteService(),
);

/// Fresh store settings from the server. Overridable in tests.
final storeSettingsLoaderProvider = Provider<Future<StoreSettings> Function()>(
  (ref) =>
      () => StoreSettingsRepository(FirebaseFirestore.instance).load(),
);

sealed class DeliveryState {
  const DeliveryState();
}

class DeliveryIdle extends DeliveryState {
  const DeliveryIdle();
}

class DeliveryLocating extends DeliveryState {
  const DeliveryLocating();
}

class DeliveryQuoted extends DeliveryState {
  const DeliveryQuoted(this.quote);
  final DeliveryQuote quote;
}

class DeliveryFailed extends DeliveryState {
  const DeliveryFailed(this.error);
  final DeliveryError error;
}

final deliveryProvider =
    NotifierProvider.autoDispose<DeliveryController, DeliveryState>(
      DeliveryController.new,
    );

/// Prices a delivery from the guest's location (owner decision P0-05):
/// browser location → road distance from the store (OSRM) → pricing
/// `deliveryFee`. Holds no money logic of its own.
class DeliveryController extends Notifier<DeliveryState> {
  @override
  DeliveryState build() => const DeliveryIdle();

  Future<void> locate() async {
    if (state is DeliveryLocating) return;
    state = const DeliveryLocating();
    final LatLng here;
    try {
      here = await ref.read(geoLocatorProvider).current();
    } on LocationDenied {
      state = const DeliveryFailed(DeliveryError.denied);
      return;
    } on Object catch (e) {
      debugPrint('delivery: location failed: $e');
      state = const DeliveryFailed(DeliveryError.unavailable);
      return;
    }
    final StoreSettings settings;
    final int meters;
    try {
      settings = await ref.read(storeSettingsLoaderProvider)();
      meters = await ref
          .read(routeServiceProvider)
          .roadMeters(settings.location, here);
    } on Object catch (e) {
      debugPrint('delivery: route failed: $e');
      state = const DeliveryFailed(DeliveryError.routeFailed);
      return;
    }
    if (!ref.mounted) return;
    state = _price(here, meters, settings);
  }

  /// Re-prices the same distance with fresh settings (after the guest
  /// accepted changed prices).
  Future<void> reprice() async {
    final current = state;
    if (current is! DeliveryQuoted) return;
    try {
      final settings = await ref.read(storeSettingsLoaderProvider)();
      if (!ref.mounted) return;
      state = _price(
        current.quote.location,
        current.quote.distanceMeters,
        settings,
      );
    } on Object {
      state = const DeliveryFailed(DeliveryError.routeFailed);
    }
  }

  void reset() => state = const DeliveryIdle();

  DeliveryState _price(LatLng here, int meters, StoreSettings settings) {
    try {
      return DeliveryQuoted(
        DeliveryQuote(
          location: here,
          distanceMeters: meters,
          fee: deliveryFee(meters, settings.delivery),
        ),
      );
    } on PricingException {
      return const DeliveryFailed(DeliveryError.outOfRange);
    }
  }
}
