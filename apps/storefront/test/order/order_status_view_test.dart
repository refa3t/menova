import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/order/presentation/order_status_view.dart';

// TEMP fixture, not owner data.
Order order(OrderStatus status, PaymentStatus pay, Fulfillment f) => Order(
  id: 'req-abcdef123456',
  requestId: 'req-abcdef123456',
  payloadHash: 'h',
  customerUid: 'u',
  customer: GuestCustomer(name: 'TEMP', phone: '01000000000', fulfillment: f),
  items: const [],
  status: status,
  paymentStatus: pay,
  paymentMethod: PaymentMethod.cash,
  deliveryFee: 0,
  total: 11500,
  definitionVersions: const {},
  rulesVersion: 1,
  createdAt: '2026-01-01T00:00:00Z',
);

Widget wrap(Order o) => MaterialApp(
  home: Scaffold(body: OrderStatusView(order: o)),
);

void main() {
  testWidgets('shows reference and separate order and payment status', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        order(
          OrderStatus.preparing,
          PaymentStatus.unpaid,
          Fulfillment.delivery,
        ),
      ),
    );
    expect(find.text('ABCDEF123456'.substring(4)), findsOneWidget);
    expect(
      find.text(AppStrings.paymentStatus(PaymentStatus.unpaid)),
      findsOneWidget,
    );
    expect(
      find.text(AppStrings.orderStatus(OrderStatus.preparing)),
      findsNWidgets(2),
    );
    expect(
      find.text(AppStrings.orderStatus(OrderStatus.outForDelivery)),
      findsOneWidget,
    );
    expect(find.text(AppStrings.price(11500)), findsOneWidget);
  });

  testWidgets('pickup orders skip the delivery step; cancelled is explicit', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(order(OrderStatus.ready, PaymentStatus.paid, Fulfillment.pickup)),
    );
    expect(
      find.text(AppStrings.orderStatus(OrderStatus.outForDelivery)),
      findsNothing,
    );
    await tester.pumpWidget(
      wrap(
        order(
          OrderStatus.cancelled,
          PaymentStatus.refunded,
          Fulfillment.pickup,
        ),
      ),
    );
    expect(find.text(AppStrings.orderCancelled), findsOneWidget);
  });
}
