import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/core/perf/perf_monitor.dart';
import 'package:storefront/core/perf/perf_overlay.dart';
import 'package:storefront/core/strings/app_strings.dart';

Widget app({required bool perf, VoidCallback? onPageTap}) => ProviderScope(
  overrides: [perfModeProvider.overrideWithValue(perf)],
  child: MaterialApp(
    builder: (context, child) => PerfGate(child: child!),
    home: Scaffold(
      body: SizedBox.expand(
        child: TextButton(onPressed: onPageTap, child: const Text('page')),
      ),
    ),
  ),
);

void main() {
  testWidgets('no overlay without the flag', (tester) async {
    await tester.pumpWidget(app(perf: false));
    expect(find.text('page'), findsOneWidget);
    expect(find.byType(PerfOverlay), findsNothing);
    expect(find.byKey(const Key('perf-overlay-text')), findsNothing);
  });

  testWidgets('the flag shows the overlay and lets taps reach the page', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(app(perf: true, onPageTap: () => taps++));
    expect(find.byType(PerfOverlay), findsOneWidget);
    expect(find.textContaining(AppStrings.perfTitle), findsOneWidget);
    expect(find.text(AppStrings.perfCopy), findsOneWidget);
    expect(find.text(AppStrings.reset), findsOneWidget);

    // A tap on the panel's text falls through to the page beneath.
    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('perf-overlay-text'))),
    );
    await tester.pump();
    expect(taps, 1);

    // Frames close together are listed as a burst once the page goes idle.
    for (var i = 0; i < 10; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(find.textContaining('#1'), findsOneWidget);

    // Unmount so the recorder's idle timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
