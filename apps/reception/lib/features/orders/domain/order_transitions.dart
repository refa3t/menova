import 'package:core/core.dart';

/// Statuses staff may move an order to next (CLAUDE.md 5.3). Mirrors the
/// Firestore rules, which enforce the same table. Delivery-only steps are
/// hidden for pickup orders. Cancel is only possible before preparing.
List<OrderStatus> nextStatuses(Order order) {
  final delivery = order.customer.fulfillment == Fulfillment.delivery;
  return switch (order.status) {
    OrderStatus.newOrder => const [OrderStatus.accepted, OrderStatus.cancelled],
    OrderStatus.accepted => const [
      OrderStatus.preparing,
      OrderStatus.cancelled,
    ],
    OrderStatus.preparing => const [OrderStatus.ready],
    OrderStatus.ready => [
      if (delivery) OrderStatus.outForDelivery,
      if (!delivery) OrderStatus.completed,
    ],
    OrderStatus.outForDelivery => const [OrderStatus.completed],
    OrderStatus.completed || OrderStatus.cancelled => const [],
  };
}

/// Payment states staff can switch to from [current].
List<PaymentStatus> nextPaymentStatuses(PaymentStatus current) => [
  for (final p in PaymentStatus.values)
    if (p != current) p,
];
