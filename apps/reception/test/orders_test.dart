import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/core/strings/app_strings.dart';
import 'package:reception/features/orders/domain/order_alerts.dart';
import 'package:reception/features/orders/presentation/kitchen_ticket.dart';
import 'package:reception/features/orders/presentation/order_card.dart';

// TEMP fixtures, not owner data.
Order order(String id, OrderStatus status) => Order(
  id: id,
  requestId: id,
  payloadHash: 'h',
  customerUid: 'u',
  customer: const GuestCustomer(
    name: 'TEMP',
    phone: '01000000000',
    fulfillment: Fulfillment.delivery,
    address: 'TEMP address',
  ),
  items: const [
    OrderItem(
      lineId: 'l',
      selection: Selection(
        productId: 'p',
        categoryId: 'c',
        definitionVersion: 1,
        sizeId: 'l',
        ingredients: {'cheese': 2, 'pepper': 1},
        notes: 'TEMP note',
      ),
      price: PriceBreakdown(
        lines: [],
        unitSubtotal: 11500,
        itemQty: 1,
        rounding: 0,
        total: 11500,
        ruleVersion: 1,
      ),
      productName: 'TEMP pizza',
      sizeName: 'كبير',
      optionNames: {'thin': 'رفيعة'},
      ingredientNames: {'cheese': 'جبنة', 'olive': 'زيتون', 'pepper': 'فلفل'},
      defaultQty: {'cheese': 1, 'olive': 1},
    ),
  ],
  status: status,
  paymentStatus: PaymentStatus.unpaid,
  paymentMethod: PaymentMethod.cash,
  deliveryFee: 0,
  total: 11500,
  definitionVersions: const {},
  rulesVersion: 1,
  createdAt: '2026-01-01T00:00:00Z',
);

void main() {
  test('first snapshot does not ring; later new orders do', () {
    final a = order('a', OrderStatus.newOrder);
    expect(newOrderIds(null, [a]), isEmpty);
    final b = order('b', OrderStatus.newOrder);
    expect(newOrderIds({'a'}, [a, b]), {'b'});
    expect(newOrderIds({'a', 'b'}, [a, b]), isEmpty);
  });

  testWidgets(
    'card shows size, option, added, removed as "without" and notes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderCard(
                order: order('req-12345678', OrderStatus.newOrder),
              ),
            ),
          ),
        ),
      );
      expect(find.text('1 × TEMP pizza'), findsOneWidget);
      expect(find.text('كبير · رفيعة'), findsOneWidget);
      expect(find.text('+ جبنة'), findsOneWidget);
      expect(find.text('+ فلفل'), findsOneWidget);
      expect(find.text('${AppStrings.without} زيتون'), findsOneWidget);
      expect(find.textContaining('TEMP note'), findsOneWidget);
      expect(find.text(AppStrings.price(11500)), findsOneWidget);
    },
  );

  testWidgets('kitchen ticket shows items, "without" lines and the credit', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: KitchenTicket(
              order: order('req-12345678', OrderStatus.newOrder),
            ),
          ),
        ),
      ),
    );
    expect(find.text('#12345678'), findsOneWidget);
    expect(find.text('1 × TEMP pizza'), findsOneWidget);
    expect(find.text('${AppStrings.without} زيتون'), findsOneWidget);
    expect(find.text('+ فلفل'), findsOneWidget);
    expect(find.text(AppStrings.credit), findsOneWidget);
  });
}
