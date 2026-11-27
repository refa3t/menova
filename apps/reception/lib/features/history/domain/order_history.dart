import 'package:core/core.dart';

import '../../../core/strings/app_strings.dart';

/// An order and the local time the server recorded it (`serverCreatedAt`).
class DayOrder {
  const DayOrder(this.order, this.at);

  final Order order;
  final DateTime at;
}

/// The local day [d] falls on, from its start to the next day's start
/// (exclusive), for querying `serverCreatedAt`.
({DateTime from, DateTime to}) dayRange(DateTime d) => (
  from: DateTime(d.year, d.month, d.day),
  to: DateTime(d.year, d.month, d.day + 1),
);

/// What an order brought in, from its frozen prices (SEC-03): the items'
/// totals less the offer's discount plus the delivery fee.
Piasters orderAmount(Order o) => o.itemsTotal - o.discount + o.deliveryFee;

/// Orders count as sales unless cancelled or refunded.
bool countsAsSale(Order o) =>
    o.status != OrderStatus.cancelled &&
    o.paymentStatus != PaymentStatus.refunded;

/// Today's summary on the history screen.
class DaySummary {
  const DaySummary({
    required this.byStatus,
    required this.sales,
    required this.cash,
    required this.delivery,
    required this.pickup,
  });

  /// Order count per status; every status is present (0 when none).
  final Map<OrderStatus, int> byStatus;

  /// Sales from frozen prices, cancelled and refunded orders excluded.
  final Piasters sales;

  /// Collected in cash: orders marked paid, whatever their status.
  final Piasters cash;

  /// Delivery and pickup counts over all the day's orders.
  final int delivery;
  final int pickup;

  int get count => byStatus.values.fold(0, (s, n) => s + n);
}

/// Pure summary of a day's [orders].
DaySummary summarize(Iterable<Order> orders) {
  final byStatus = {for (final s in OrderStatus.values) s: 0};
  Piasters sales = 0;
  Piasters cash = 0;
  var delivery = 0;
  var pickup = 0;
  for (final o in orders) {
    byStatus[o.status] = byStatus[o.status]! + 1;
    if (countsAsSale(o)) sales += orderAmount(o);
    if (o.paymentStatus == PaymentStatus.paid) cash += orderAmount(o);
    switch (o.customer.fulfillment) {
      case Fulfillment.delivery:
        delivery++;
      case Fulfillment.pickup:
        pickup++;
    }
  }
  return DaySummary(
    byStatus: byStatus,
    sales: sales,
    cash: cash,
    delivery: delivery,
    pickup: pickup,
  );
}

const _arabicDigits = '٠١٢٣٤٥٦٧٨٩';
const _persianDigits = '۰۱۲۳۴۵۶۷۸۹';

/// [s] with Arabic-Indic and Persian digits turned into Latin ones.
String latinDigits(String s) {
  final out = StringBuffer();
  for (final ch in s.split('')) {
    final a = _arabicDigits.indexOf(ch);
    final p = _persianDigits.indexOf(ch);
    out.write(
      a >= 0
          ? '$a'
          : p >= 0
          ? '$p'
          : ch,
    );
  }
  return out.toString();
}

/// True when [o] matches [query] by order reference (short or full id,
/// with or without "#"), customer name, or phone. An empty query matches.
bool matchesQuery(Order o, String query) {
  final q = latinDigits(query).trim().toLowerCase();
  if (q.isEmpty) return true;
  final ref = q.startsWith('#') ? q.substring(1) : q;
  if (ref.isNotEmpty &&
      (o.id.toLowerCase().contains(ref) ||
          AppStrings.shortReference(o.id).toLowerCase().contains(ref))) {
    return true;
  }
  if (o.customer.name.toLowerCase().contains(q)) return true;
  final digits = q.replaceAll(RegExp(r'[^0-9]'), '');
  // Phone search needs a few digits, so a stray digit does not match all.
  return digits.length >= 3 && o.customer.phone.contains(digits);
}

/// [orders] matching [query], order kept.
List<DayOrder> filterOrders(List<DayOrder> orders, String query) => [
  for (final d in orders)
    if (matchesQuery(d.order, query)) d,
];
