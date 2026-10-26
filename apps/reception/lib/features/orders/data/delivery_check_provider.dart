import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../domain/delivery_check.dart';

final _storeSettingsProvider = StreamProvider<StoreSettings>(
  (ref) => FirebaseFirestore.instance
      .doc('settings/store')
      .snapshots()
      .map((d) => StoreSettings.fromJson(d.data()!)),
);

/// Road distance in meters from OSRM (free, no API key; same service the
/// storefront prices with).
Future<int> osrmRoadMeters(LatLng from, LatLng to) async {
  final uri = Uri.parse(
    'https://router.project-osrm.org/route/v1/driving/'
    '${from.lng},${from.lat};${to.lng},${to.lat}?overview=false',
  );
  final res = await http.get(uri).timeout(const Duration(seconds: 12));
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  final routes = body['routes'] as List?;
  if (res.statusCode != 200 ||
      body['code'] != 'Ok' ||
      routes == null ||
      routes.isEmpty) {
    throw StateError('OSRM ${res.statusCode} ${body['code']}');
  }
  return ((routes.first as Map)['distance'] as num).round();
}

/// One re-measure per delivery order (keyed by what the fee depends on, so
/// status changes do not call the routing service again).
final deliveryCheckProvider =
    FutureProvider.family<DeliveryCheck, ({String id, LatLng to, int fee})>((
      ref,
      key,
    ) async {
      final settings = await ref.watch(_storeSettingsProvider.future);
      try {
        final meters = await osrmRoadMeters(settings.location, key.to);
        return checkDelivery(key.fee, settings, meters);
      } on Object catch (e) {
        debugPrint('delivery check failed: $e');
        return const DeliveryCheck.unverified();
      }
    });

/// Key for [deliveryCheckProvider]; null for pickup or a missing location.
({String id, LatLng to, int fee})? deliveryCheckKey(Order order) {
  final to = order.customer.location;
  if (order.customer.fulfillment != Fulfillment.delivery || to == null) {
    return null;
  }
  return (id: order.id, to: to, fee: order.deliveryFee);
}
