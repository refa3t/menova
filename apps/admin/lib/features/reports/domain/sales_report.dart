import 'package:core/core.dart';

/// An order and the local time the server recorded it (`serverCreatedAt`).
class PlacedOrder {
  const PlacedOrder(this.order, this.at);

  final Order order;
  final DateTime at;
}

/// Orders count as sales unless cancelled or refunded.
bool countsAsSale(Order o) =>
    o.status != OrderStatus.cancelled &&
    o.paymentStatus != PaymentStatus.refunded;

/// Totals of sold orders from their frozen prices (SEC-03): the items'
/// totals, the discounts offers took off (P3-09) and the delivery fees.
class SalesTotals {
  const SalesTotals({
    this.orders = 0,
    this.items = 0,
    this.discount = 0,
    this.delivery = 0,
  });

  final int orders;
  final Piasters items;
  final Piasters discount;
  final Piasters delivery;

  Piasters get sales => items - discount + delivery;

  /// Sales per order; 0 without orders.
  Piasters get average => orders == 0 ? 0 : (sales / orders).round();

  SalesTotals plus(Order o) => SalesTotals(
    orders: orders + 1,
    items: items + o.itemsTotal,
    discount: discount + o.discount,
    delivery: delivery + o.deliveryFee,
  );
}

/// Sales of the day or week that starts at [start].
class PeriodSales {
  const PeriodSales(this.start, this.totals);

  final DateTime start;
  final SalesTotals totals;
}

/// A product or add-on: how many were sold and what they brought in.
class Ranked {
  const Ranked({
    required this.id,
    required this.name,
    required this.count,
    required this.revenue,
  });

  final String id;
  final String name;
  final int count;
  final Piasters revenue;
}

/// The local day [d] falls on.
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// The Saturday that starts the week of [d] (the Egyptian week).
DateTime weekStart(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - DateTime.saturday) % 7);

/// The last [days] local days, today included: from the first day's start
/// to tomorrow's start (exclusive).
({DateTime from, DateTime to}) lastDays(DateTime now, int days) => (
  from: DateTime(now.year, now.month, now.day - days + 1),
  to: DateTime(now.year, now.month, now.day + 1),
);

/// The owner's sales report over the local days from [from] up to [to]
/// (exclusive) (P3-08). Cancelled and refunded orders are left out.
class SalesReport {
  const SalesReport({
    required this.from,
    required this.to,
    required this.totals,
    required this.excluded,
    required this.unreadable,
    required this.days,
    required this.weeks,
    required this.bestSellers,
    required this.addOns,
  });

  final DateTime from;
  final DateTime to;
  final SalesTotals totals;

  /// Orders of the period left out: cancelled or refunded.
  final int excluded;

  /// Order documents that could not be read.
  final int unreadable;

  /// Every day of the period, oldest first, days without sales included.
  final List<PeriodSales> days;

  /// The weeks the period touches, oldest first.
  final List<PeriodSales> weeks;

  /// Products by quantity sold.
  final List<Ranked> bestSellers;

  /// Paid extras (ingredients above the default) and paid options, by how
  /// many were ordered.
  final List<Ranked> addOns;

  factory SalesReport.build(
    Iterable<PlacedOrder> placed, {
    required DateTime from,
    required DateTime to,
    int unreadable = 0,
  }) {
    var totals = const SalesTotals();
    var excluded = 0;
    final byDay = <DateTime, SalesTotals>{};
    final byWeek = <DateTime, SalesTotals>{};
    final products = <String, Ranked>{};
    final addOns = <String, Ranked>{};
    void tally(
      Map<String, Ranked> into,
      String id,
      String name,
      int count,
      Piasters revenue,
    ) {
      final was = into[id];
      // Oldest first, so the latest name an item was sold under wins.
      into[id] = Ranked(
        id: id,
        name: name,
        count: (was?.count ?? 0) + count,
        revenue: (was?.revenue ?? 0) + revenue,
      );
    }

    final inPeriod =
        placed.where((p) => !p.at.isBefore(from) && p.at.isBefore(to)).toList()
          ..sort((a, b) => a.at.compareTo(b.at));
    for (final p in inPeriod) {
      final o = p.order;
      if (!countsAsSale(o)) {
        excluded++;
        continue;
      }
      totals = totals.plus(o);
      final day = dayOf(p.at), week = weekStart(p.at);
      byDay[day] = (byDay[day] ?? const SalesTotals()).plus(o);
      byWeek[week] = (byWeek[week] ?? const SalesTotals()).plus(o);
      for (final i in o.items) {
        tally(
          products,
          i.selection.productId,
          i.productName,
          i.qty,
          i.price.total,
        );
        // Price lines are per unit of the item.
        for (final l in i.price.lines) {
          final ref = l.refId;
          if (ref == null || l.amount <= 0) continue;
          if (l.kind == PriceLineKind.extra) {
            tally(
              addOns,
              'ingredient:$ref',
              i.ingredientNames[ref] ?? ref,
              l.qty * i.qty,
              l.amount * i.qty,
            );
          } else if (l.kind == PriceLineKind.option) {
            tally(
              addOns,
              'option:$ref',
              i.optionNames[ref] ?? ref,
              i.qty,
              l.amount * i.qty,
            );
          }
        }
      }
    }

    List<Ranked> ranked(Iterable<Ranked> list) => list.toList()
      ..sort(
        (a, b) => b.count != a.count
            ? b.count.compareTo(a.count)
            : b.revenue != a.revenue
            ? b.revenue.compareTo(a.revenue)
            : a.name.compareTo(b.name),
      );

    return SalesReport(
      from: from,
      to: to,
      totals: totals,
      excluded: excluded,
      unreadable: unreadable,
      days: [
        for (
          var d = dayOf(from);
          d.isBefore(to);
          d = DateTime(d.year, d.month, d.day + 1)
        )
          PeriodSales(d, byDay[d] ?? const SalesTotals()),
      ],
      weeks: [
        for (
          var w = weekStart(from);
          w.isBefore(to);
          w = DateTime(w.year, w.month, w.day + 7)
        )
          PeriodSales(w, byWeek[w] ?? const SalesTotals()),
      ],
      bestSellers: ranked(products.values),
      addOns: ranked(addOns.values),
    );
  }
}
