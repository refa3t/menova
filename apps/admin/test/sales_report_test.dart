import 'package:admin/features/reports/domain/sales_report.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

OrderItem item(
  String productId,
  String name, {
  int qty = 1,
  int base = 10000,
  List<PriceLine> more = const [],
  Map<String, String> ingredientNames = const {},
  Map<String, String> optionNames = const {},
}) {
  final lines = [PriceLine(kind: PriceLineKind.base, amount: base), ...more];
  final unit = lines.fold(0, (s, l) => s + l.amount);
  return OrderItem(
    lineId: 'line-$productId',
    selection: Selection(
      productId: productId,
      categoryId: 'cat_a',
      definitionVersion: 1,
    ),
    price: PriceBreakdown(
      lines: lines,
      unitSubtotal: unit,
      itemQty: qty,
      rounding: 0,
      total: unit * qty,
      ruleVersion: 2,
    ),
    productName: name,
    ingredientNames: ingredientNames,
    optionNames: optionNames,
  );
}

PlacedOrder placed(
  DateTime at,
  List<OrderItem> items, {
  OrderStatus status = OrderStatus.completed,
  PaymentStatus payment = PaymentStatus.paid,
  int deliveryFee = 0,
}) {
  final id = 'o${at.microsecondsSinceEpoch}';
  return PlacedOrder(
    Order(
      id: id,
      requestId: id,
      payloadHash: 'h',
      customerUid: 'u',
      customer: const GuestCustomer(
        name: 'Test',
        phone: '01000000000',
        fulfillment: Fulfillment.pickup,
      ),
      items: items,
      status: status,
      paymentStatus: payment,
      paymentMethod: PaymentMethod.cash,
      deliveryFee: deliveryFee,
      total: items.fold(0, (s, i) => s + i.price.total) + deliveryFee,
      definitionVersions: const {},
      rulesVersion: 2,
      createdAt: at.toUtc().toIso8601String(),
    ),
    at,
  );
}

void main() {
  // Sunday 1 November 2026, afternoon: the last 7 days run Monday 26
  // October to Sunday 1 November; weeks start on Saturday 24 and 31.
  final now = DateTime(2026, 11, 1, 15, 30);
  final period = lastDays(now, 7);
  final orders = [
    // Before the period: not counted at all.
    placed(DateTime(2026, 10, 20, 12), [item('p_a', 'A')]),
    placed(DateTime(2026, 10, 26, 10), [
      item('p_a', 'A old name', qty: 2),
    ], deliveryFee: 2500),
    placed(
      DateTime(2026, 10, 31, 20),
      [
        item(
          'p_b',
          'B',
          base: 15000,
          more: const [
            PriceLine(
              kind: PriceLineKind.extra,
              refId: 'cheese',
              qty: 2,
              amount: 3000,
            ),
          ],
          ingredientNames: const {'cheese': 'جبنة'},
        ),
      ],
      status: OrderStatus.newOrder,
      payment: PaymentStatus.unpaid,
    ),
    placed(DateTime(2026, 11, 1, 12), [
      item('p_b', 'B'),
    ], status: OrderStatus.cancelled),
    placed(DateTime(2026, 11, 1, 13), [
      item('p_b', 'B'),
    ], payment: PaymentStatus.refunded),
    placed(DateTime(2026, 11, 1, 14), [
      item(
        'p_a',
        'A',
        more: const [
          PriceLine(kind: PriceLineKind.option, refId: 'stuffed', amount: 4500),
          // A free choice is not an add-on.
          PriceLine(kind: PriceLineKind.option, refId: 'regular', amount: 0),
        ],
        optionNames: const {'stuffed': 'ستافت كراست', 'regular': 'عادية'},
      ),
    ]),
  ];
  final report = SalesReport.build(
    orders,
    from: period.from,
    to: period.to,
    unreadable: 1,
  );

  test('the period is the last days, today included', () {
    expect(period.from, DateTime(2026, 10, 26));
    expect(period.to, DateTime(2026, 11, 2));
    // Across a month end, by the calendar.
    final march = lastDays(DateTime(2026, 3, 1, 9), 2);
    expect(march.from, DateTime(2026, 2, 28));
    expect(march.to, DateTime(2026, 3, 2));
  });

  test('weeks start on Saturday', () {
    expect(weekStart(DateTime(2026, 10, 31)), DateTime(2026, 10, 31));
    expect(weekStart(DateTime(2026, 11, 1, 23, 59)), DateTime(2026, 10, 31));
    expect(weekStart(DateTime(2026, 11, 6, 8)), DateTime(2026, 10, 31));
    expect(weekStart(DateTime(2026, 10, 30)), DateTime(2026, 10, 24));
  });

  test('totals leave out cancelled and refunded orders', () {
    final t = report.totals;
    expect(t.orders, 3);
    expect(t.items, 20000 + 18000 + 14500);
    expect(t.delivery, 2500);
    expect(t.sales, 55000);
    expect(t.average, 18333); // 550 / 3, rounded to the piaster
    expect(report.excluded, 2);
    expect(report.unreadable, 1);
  });

  test('every day of the period, and the weeks it touches', () {
    expect(report.days, hasLength(7));
    expect(report.days.first.start, DateTime(2026, 10, 26));
    expect(report.days.first.totals.sales, 22500);
    expect(report.days[1].totals.orders, 0);
    expect(report.days[5].totals.sales, 18000); // Saturday 31
    expect(report.days.last.start, DateTime(2026, 11, 1));
    expect(report.days.last.totals.orders, 1);
    expect(report.days.last.totals.sales, 14500);

    expect(
      [for (final w in report.weeks) w.start],
      [DateTime(2026, 10, 24), DateTime(2026, 10, 31)],
    );
    expect(report.weeks.first.totals.sales, 22500);
    expect(report.weeks.last.totals.orders, 2);
    expect(report.weeks.last.totals.sales, 32500);
  });

  test('best sellers by quantity, under their latest name', () {
    expect(
      [for (final r in report.bestSellers) (r.name, r.count)],
      [('A', 3), ('B', 1)],
    );
    expect(report.bestSellers.first.revenue, 20000 + 14500);
  });

  test('add-ons are paid extras and paid options', () {
    expect(
      [for (final r in report.addOns) (r.name, r.count, r.revenue)],
      [('جبنة', 2, 3000), ('ستافت كراست', 1, 4500)],
    );
  });

  test('extras count per unit of the item', () {
    final r = SalesReport.build(
      [
        placed(DateTime(2026, 11, 1, 10), [
          item(
            'p_a',
            'A',
            qty: 3,
            more: const [
              PriceLine(
                kind: PriceLineKind.extra,
                refId: 'olive',
                qty: 2,
                amount: 2000,
              ),
            ],
          ),
        ]),
      ],
      from: period.from,
      to: period.to,
    );
    // Three pizzas with two extra olives each.
    expect(r.addOns.single.count, 6);
    expect(r.addOns.single.revenue, 6000);
    expect(r.addOns.single.name, 'olive'); // no frozen name: the id
  });
}
