import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/features/reports/data/sales_report_provider.dart';
import 'package:admin/features/reports/domain/sales_report.dart';
import 'package:admin/features/reports/presentation/reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

SalesReport reportFor(int days) {
  final p = lastDays(DateTime(2026, 11, 1, 12), days);
  return SalesReport(
    from: p.from,
    to: p.to,
    totals: const SalesTotals(orders: 4, items: 120000, delivery: 5000),
    excluded: 1,
    unreadable: 0,
    days: [
      for (var i = 0; i < days; i++)
        PeriodSales(
          DateTime(p.from.year, p.from.month, p.from.day + i),
          i == days - 1
              ? const SalesTotals(orders: 4, items: 120000, delivery: 5000)
              : const SalesTotals(),
        ),
    ],
    weeks: [PeriodSales(weekStart(p.from), const SalesTotals())],
    bestSellers: const [
      Ranked(id: 'a', name: 'مارجريتا', count: 3, revenue: 90000),
      Ranked(id: 'b', name: 'كريب نوتيلا', count: 1, revenue: 30000),
    ],
    addOns: const [
      Ranked(
        id: 'option:stuffed',
        name: 'ستافت كراست',
        count: 2,
        revenue: 9000,
      ),
    ],
  );
}

void main() {
  testWidgets('shows the totals, the rankings and a table twin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final asked = <int>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          salesReportProvider.overrideWith((ref, days) async {
            asked.add(days);
            return reportFor(days);
          }),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ReportsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(asked, [30]);
    expect(find.text(AppStrings.amount(125000)), findsOneWidget); // sales
    expect(find.text(AppStrings.amount(5000)), findsOneWidget); // delivery
    expect(find.text('مارجريتا'), findsOneWidget);
    expect(find.text('ستافت كراست'), findsOneWidget);
    expect(find.text(AppStrings.excluded(1)), findsOneWidget);

    // The daily chart has a table twin with every day.
    await tester.tap(find.text(AppStrings.showTable));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.day(DateTime(2026, 11, 1))), findsOneWidget);
    expect(find.text(AppStrings.day(DateTime(2026, 10, 3))), findsOneWidget);

    // Another period reads its own report.
    await tester.tap(find.text(AppStrings.lastDaysLabel(7)));
    await tester.pumpAndSettle();
    expect(asked, [30, 7]);
    expect(find.text(AppStrings.day(DateTime(2026, 10, 3))), findsNothing);
  });
}
