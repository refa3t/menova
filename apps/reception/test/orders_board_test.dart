import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/core/strings/app_strings.dart';
import 'package:reception/features/orders/domain/order_board.dart';
import 'package:reception/features/orders/domain/order_timing.dart';
import 'package:reception/features/orders/presentation/board_clock.dart';
import 'package:reception/features/orders/presentation/order_card.dart';
import 'package:reception/features/orders/presentation/order_timer_badge.dart';
import 'package:reception/features/orders/presentation/orders_board.dart';

import 'orders_test.dart' show order;

final t0 = DateTime.utc(2026, 1, 1, 12);

BoardOrder placed(String id, OrderStatus s, {int minutesAgo = 0}) => BoardOrder(
  order(id, s),
  placedAt: t0.subtract(Duration(minutes: minutesAgo)),
);

final sample = [
  placed('n1', OrderStatus.newOrder, minutesAgo: 2),
  placed('n2', OrderStatus.newOrder, minutesAgo: 9),
  placed('a1', OrderStatus.accepted, minutesAgo: 5),
  placed('p1', OrderStatus.preparing, minutesAgo: 30),
  placed('r1', OrderStatus.ready, minutesAgo: 1),
  placed('d1', OrderStatus.outForDelivery, minutesAgo: 20),
];

Widget board(List<BoardOrder> orders, {Size size = const Size(1400, 900)}) =>
    MediaQuery(
      data: MediaQueryData(size: size),
      child: MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox.fromSize(
              size: size,
              child: OrdersBoard(
                orders: orders,
                cardBuilder: (context, b) => Text('card ${b.id}'),
              ),
            ),
          ),
        ),
      ),
    );

void main() {
  group('grouping', () {
    test('statuses map to the four columns; finished orders leave', () {
      final g = groupByColumn([
        ...sample,
        placed('c1', OrderStatus.completed),
        placed('x1', OrderStatus.cancelled),
      ]);
      List<String> ids(BoardColumn c) => [for (final b in g[c]!) b.id];
      expect(ids(BoardColumn.incoming), ['n2', 'n1'], reason: 'oldest first');
      expect(ids(BoardColumn.kitchen), ['p1', 'a1']);
      expect(ids(BoardColumn.ready), ['r1']);
      expect(ids(BoardColumn.onTheWay), ['d1']);
    });

    test('server time wins over the client createdAt', () {
      final o = order('a', OrderStatus.newOrder);
      expect(BoardOrder.of(o).placedAt, DateTime.parse(o.createdAt));
      expect(BoardOrder.of(o, serverCreatedAt: t0).placedAt, t0);
    });

    testWidgets('wide screen shows four columns with counts', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(board(sample));
      for (final c in BoardColumn.values) {
        expect(find.byKey(ValueKey('column-${c.name}')), findsOneWidget);
      }
      expect(
        find.text(AppStrings.withCount(AppStrings.columnIncoming, 2)),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.withCount(AppStrings.columnKitchen, 2)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('column-kitchen')),
          matching: find.text('card p1'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('column-onTheWay')),
          matching: find.text('card d1'),
        ),
        findsOneWidget,
      );
      expect(find.byType(TabBar), findsNothing);
    });

    testWidgets('phone shows tabs with counts, one column at a time', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(board(sample, size: const Size(375, 812)));
      expect(find.byType(TabBar), findsOneWidget);
      expect(
        find.text(AppStrings.withCount(AppStrings.columnReady, 1)),
        findsOneWidget,
      );
      expect(find.text('card n1'), findsOneWidget);
      expect(find.text('card r1'), findsNothing);
      final readyTab = find.text(
        AppStrings.withCount(AppStrings.columnReady, 1),
      );
      await tester.ensureVisible(readyTab);
      await tester.pumpAndSettle();
      await tester.tap(readyTab);
      await tester.pumpAndSettle();
      expect(find.text('card r1'), findsOneWidget);
      expect(find.text('card n1'), findsNothing);
    });

    testWidgets('empty column says so', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(board([placed('n1', OrderStatus.newOrder)]));
      expect(find.text(AppStrings.emptyColumn), findsNWidgets(3));
    });
  });

  group('timers', () {
    test('thresholds', () {
      expect(
        urgencyOf(const Duration(minutes: 14, seconds: 59)),
        Urgency.onTime,
      );
      expect(urgencyOf(OrderTiming.warnAfter), Urgency.warning);
      expect(urgencyOf(OrderTiming.lateAfter), Urgency.late);
      expect(waitedFor(t0.add(const Duration(minutes: 1)), t0), Duration.zero);
      expect(waitedFor(null, t0), Duration.zero);
      expect(lateCount(sample, t0), 1);
    });

    Color badgeColor(WidgetTester tester, Urgency u) =>
        (tester
                    .widget<Container>(find.byKey(ValueKey('timer-${u.name}')))
                    .decoration!
                as BoxDecoration)
            .color!;

    testWidgets('badge ticks with one clock and turns yellow then red', (
      tester,
    ) async {
      var now = t0;
      final clock = BoardClock(
        now: () => now,
        every: const Duration(seconds: 15),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                OrderTimerBadge(placedAt: t0, now: clock),
                LateCount(
                  orders: [placed('x', OrderStatus.newOrder)],
                  now: clock,
                ),
              ],
            ),
          ),
        ),
      );
      final scheme = Theme.of(tester.element(find.byType(Column))).colorScheme;

      expect(find.text(AppStrings.minutesWaited(0)), findsOneWidget);
      expect(
        badgeColor(tester, Urgency.onTime),
        urgencyColors(scheme, Urgency.onTime).background,
      );
      expect(find.text(AppStrings.lateOrders(1)), findsNothing);

      now = t0.add(const Duration(minutes: 16));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text(AppStrings.minutesWaited(16)), findsOneWidget);
      expect(
        badgeColor(tester, Urgency.warning),
        urgencyColors(scheme, Urgency.warning).background,
      );

      now = t0.add(const Duration(minutes: 26));
      await tester.pump(const Duration(seconds: 15));
      expect(find.text(AppStrings.minutesWaited(26)), findsOneWidget);
      expect(
        badgeColor(tester, Urgency.late),
        urgencyColors(scheme, Urgency.late).background,
      );
      expect(find.text(AppStrings.lateOrders(1)), findsOneWidget);
      clock.dispose();
    });
  });

  testWidgets('compact card keeps the flags and opens the details', (
    tester,
  ) async {
    var expanded = false;
    late StateSetter set;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) {
                set = setState;
                return OrderCard(
                  order: order('req-12345678', OrderStatus.newOrder),
                  expanded: expanded,
                  onToggleExpanded: () => set(() => expanded = !expanded),
                  actions: const Text('actions'),
                );
              },
            ),
          ),
        ),
      ),
    );
    expect(find.text('1 × TEMP pizza'), findsOneWidget);
    expect(find.text('actions'), findsOneWidget);
    expect(find.text(AppStrings.price(11500)), findsOneWidget);
    expect(find.text('${AppStrings.without} زيتون'), findsNothing);
    await tester.tap(find.text(AppStrings.showDetails));
    await tester.pump();
    expect(find.text('${AppStrings.without} زيتون'), findsOneWidget);
    expect(find.text(AppStrings.hideDetails), findsOneWidget);
  });
}
