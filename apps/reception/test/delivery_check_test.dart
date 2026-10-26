import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/features/orders/domain/delivery_check.dart';
import 'package:reception/features/orders/presentation/order_card.dart';

import 'orders_test.dart' show order;

// TEMP fixture shaped like settings/store.
const settings = StoreSettings(
  location: LatLng(30.4468569, 31.1910437),
  delivery: DeliverySettings(
    perKm: 600,
    minFee: 2500,
    maxDistanceMeters: 15000,
  ),
);

Order deliveryOrder({int fee = 3000}) {
  final o = order('d1', OrderStatus.newOrder);
  return Order.fromJson({
    ...o.toJson(),
    'customer': {
      ...o.customer.toJson(),
      'location': {'lat': 30.46, 'lng': 31.18},
      'distanceMeters': 4300,
    },
    'deliveryFee': fee,
    'total': 11500 + fee,
  });
}

void main() {
  test('fee matches the re-measured road distance', () {
    final c = checkDelivery(3000, settings, 4300);
    expect(c.result, DeliveryCheckResult.matches);
    expect(c.expectedFee, 3000);
  });

  test('a lower fee than the distance needs is a mismatch', () {
    final c = checkDelivery(2500, settings, 6200); // 7 km × 6 = 42
    expect(c.result, DeliveryCheckResult.mismatch);
    expect(c.expectedFee, 4200);
  });

  test('beyond the delivery range is a mismatch without a fee', () {
    final c = checkDelivery(9000, settings, 16000);
    expect(c.result, DeliveryCheckResult.mismatch);
    expect(c.expectedFee, isNull);
  });

  testWidgets('card shows distance, fee, map link and a flagged mismatch', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            child: OrderCard(
              order: deliveryOrder(),
              deliveryCheck: checkDelivery(3000, settings, 6200),
            ),
          ),
        ),
      ),
    );
    expect(find.text('4.3 كم بالطريق'), findsOneWidget);
    expect(find.text('رسوم التوصيل'), findsOneWidget);
    expect(find.text('30 ج.م'), findsOneWidget);
    expect(find.text('الموقع على الخريطة'), findsOneWidget);
    expect(find.textContaining('لا تطابق المسافة الفعلية'), findsOneWidget);
  });
}
