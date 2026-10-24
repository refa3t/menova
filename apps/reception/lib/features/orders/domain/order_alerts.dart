import 'package:core/core.dart';

/// Statuses shown on the live board (completed and cancelled drop off).
const activeStatuses = {
  OrderStatus.newOrder,
  OrderStatus.accepted,
  OrderStatus.preparing,
  OrderStatus.ready,
  OrderStatus.outForDelivery,
};

/// Ids of `new` orders not seen before, which should ring the alert. The
/// first snapshot only seeds [seen] so opening the board does not ring.
Set<String> newOrderIds(Set<String>? seen, List<Order> current) {
  final fresh = {
    for (final o in current)
      if (o.status == OrderStatus.newOrder) o.id,
  };
  if (seen == null) return const {};
  return fresh.difference(seen);
}
