import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/features/history/domain/order_history.dart';

// TEMP fixtures, not owner data.
OrderItem item(int total) => OrderItem(
  lineId: 'l$total',
  selection: const Selection(
    productId: 'p',
    categoryId: 'c',
    definitionVersion: 1,
  ),
  price: PriceBreakdown(
    lines: const [],
    unitSubtotal: total,
    itemQty: 1,
    rounding: 0,
    total: total,
    ruleVersion: 1,
  ),
  productName: 'TEMP',
);

Order order(
  String id, {
  OrderStatus status = OrderStatus.newOrder,
  PaymentStatus payment = PaymentStatus.unpaid,
  Fulfillment fulfillment = Fulfillment.pickup,
  List<int> items = const [10000],
  int fee = 0,
  int discount = 0,
  String name = 'TEMP name',
  String phone = '01000000000',
}) => Order(
  id: id,
  requestId: id,
  payloadHash: 'h',
  customerUid: 'u',
  customer: GuestCustomer(name: name, phone: phone, fulfillment: fulfillment),
  items: [for (final t in items) item(t)],
  status: status,
  paymentStatus: payment,
  paymentMethod: PaymentMethod.cash,
  deliveryFee: fee,
  discount: discount,
  total: items.fold(0, (s, t) => s + t) - discount + fee,
  definitionVersions: const {},
  rulesVersion: 1,
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  group('summarize', () {
    test('empty day is all zeros with every status present', () {
      final s = summarize(const []);
      expect(s.count, 0);
      expect(s.sales, 0);
      expect(s.cash, 0);
      expect(s.delivery, 0);
      expect(s.pickup, 0);
      expect(s.byStatus.keys, OrderStatus.values);
      expect(s.byStatus.values.every((n) => n == 0), isTrue);
    });

    test('counts by status and fulfillment, sums frozen prices', () {
      final s = summarize([
        // Delivered and paid: 150 + 20 fee − 10 off = 160.
        order(
          'a',
          status: OrderStatus.completed,
          payment: PaymentStatus.paid,
          fulfillment: Fulfillment.delivery,
          items: [10000, 5000],
          fee: 2000,
          discount: 1000,
        ),
        // Active, unpaid: counts as sales, not cash.
        order('b', status: OrderStatus.preparing, items: [8000]),
        // Cancelled: no sales.
        order('c', status: OrderStatus.cancelled, items: [30000]),
        // Refunded: no sales and no cash.
        order(
          'd',
          status: OrderStatus.completed,
          payment: PaymentStatus.refunded,
          fulfillment: Fulfillment.delivery,
          items: [40000],
        ),
      ]);
      expect(s.count, 4);
      expect(s.byStatus[OrderStatus.completed], 2);
      expect(s.byStatus[OrderStatus.preparing], 1);
      expect(s.byStatus[OrderStatus.cancelled], 1);
      expect(s.byStatus[OrderStatus.newOrder], 0);
      expect(s.sales, 16000 + 8000);
      expect(s.cash, 16000);
      expect(s.delivery, 2);
      expect(s.pickup, 2);
    });

    test('order amount ignores the stored total', () {
      final o = order('x', items: [10000], fee: 500, discount: 200);
      expect(orderAmount(o), 10300);
    });
  });

  group('search', () {
    final orders = [
      DayOrder(
        order('req-abcd1234', name: 'Ahmed Ali', phone: '01012345678'),
        DateTime(2026, 1, 1, 10),
      ),
      DayOrder(
        order('req-wxyz9876', name: 'محمد', phone: '01198765432'),
        DateTime(2026, 1, 1, 9),
      ),
    ];
    List<String> ids(String q) => [
      for (final d in filterOrders(orders, q)) d.order.id,
    ];

    test('empty query keeps all, in order', () {
      expect(ids(''), ['req-abcd1234', 'req-wxyz9876']);
      expect(ids('   '), ['req-abcd1234', 'req-wxyz9876']);
    });

    test('by reference, with or without # and in any case', () {
      expect(ids('#ABCD1234'), ['req-abcd1234']);
      expect(ids('wxyz'), ['req-wxyz9876']);
      expect(ids('req-abcd1234'), ['req-abcd1234']);
    });

    test('by customer name, ignoring case', () {
      expect(ids('ahmed'), ['req-abcd1234']);
      expect(ids('محمد'), ['req-wxyz9876']);
    });

    test('by phone, Arabic digits too', () {
      expect(ids('0101234'), ['req-abcd1234']);
      expect(ids('٠١١٩٨'), ['req-wxyz9876']);
    });

    test('no match gives nothing', () {
      expect(ids('zzz'), isEmpty);
      expect(ids('55555'), isEmpty);
    });
  });

  test('day range covers the local day only', () {
    final r = dayRange(DateTime(2026, 3, 31, 23, 59));
    expect(r.from, DateTime(2026, 3, 31));
    expect(r.to, DateTime(2026, 4, 1));
  });
}
