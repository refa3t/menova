import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/core/strings/app_strings.dart';
import 'package:reception/features/history/data/day_orders_provider.dart';
import 'package:reception/features/history/domain/order_history.dart';
import 'package:reception/features/history/presentation/history_screen.dart';

import 'history_test.dart' show order;

void main() {
  testWidgets('shows the summary, lists orders and filters by search', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final orders = [
      DayOrder(
        order(
          'req-abcd1234',
          name: 'TEMP Ahmed',
          status: OrderStatus.completed,
          payment: PaymentStatus.paid,
        ),
        DateTime(2026, 1, 1, 10, 5),
      ),
      DayOrder(
        order('req-wxyz9876', name: 'TEMP Sara'),
        DateTime(2026, 1, 1, 9),
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayOrdersProvider.overrideWith((ref, day) => Stream.value(orders)),
        ],
        child: const MaterialApp(home: HistoryScreen()),
      ),
    );
    await tester.pump();

    expect(find.text(AppStrings.history), findsOneWidget);
    expect(
      find.text(
        AppStrings.countOf(AppStrings.orderStatus(OrderStatus.completed), 1),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('TEMP Ahmed'), findsOneWidget);
    expect(find.textContaining('TEMP Sara'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'sara');
    await tester.pump();
    expect(find.textContaining('TEMP Ahmed'), findsNothing);
    expect(find.textContaining('TEMP Sara'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'nobody');
    await tester.pump();
    expect(find.text(AppStrings.noMatches), findsOneWidget);
  });
}
