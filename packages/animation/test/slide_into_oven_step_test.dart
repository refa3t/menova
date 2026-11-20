import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// SlideIntoOven: draws at every stage and on degenerate params without
/// touching state, is left out with reduced motion, and runs its lifecycle
/// inside a sequence like any step.
void main() {
  const rect = Rect.fromLTWH(60, 260, 220, 220);
  const productKey = Key('product');
  AnimStepInput input(
    Map<String, Object?> params, {
    Rect at = rect,
    bool reduceMotion = false,
  }) => AnimStepInput(
    product: const SizedBox.expand(key: productKey),
    productRect: at,
    cartTarget: const Offset(320, 20),
    params: params,
    reduceMotion: reduceMotion,
  );

  Future<void> render(
    WidgetTester tester,
    AnimStepInput input,
    double t,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => animSteps['SlideIntoOven']!.build(
            context,
            AnimFrame(
              t: t,
              elapsed: Duration(
                milliseconds: t.isFinite ? (t * 1800).round() : 0,
              ),
            ),
            input,
          ),
        ),
      ),
    );
  }

  test('the step is registered for definitions', () {
    expect(animSteps['SlideIntoOven'], isA<SlideIntoOvenStep>());
    expect(animationStepKeys, contains('SlideIntoOven'));
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('draws from start to end (reduce motion $reduceMotion)', (
      tester,
    ) async {
      final params = {'bubbles': 18, 'bubbleArea': 0.7, 'tilt': 0.6};
      for (var i = 0; i <= 20; i++) {
        await render(
          tester,
          input(params, reduceMotion: reduceMotion),
          i / 20,
        );
        expect(tester.takeException(), isNull, reason: 't ${i / 20}');
        expect(find.byKey(productKey), findsOneWidget);
      }
    });
  }

  testWidgets('starts where the product is and ends out of the oven', (
    tester,
  ) async {
    await render(tester, input(const {}), 0);
    expect(tester.getCenter(find.byKey(productKey)), rect.center);
    // Inside the oven: higher up the screen, smaller.
    await render(tester, input(const {}), 0.5);
    final inside = tester.getRect(find.byKey(productKey));
    expect(inside.center.dy, lessThan(rect.top));
    expect(inside.width, lessThan(rect.width));
    // Out again, at its place, scaled to where Swap takes over.
    await render(tester, input(const {'shrinkTo': 0.9}), 1);
    final out = tester.getRect(find.byKey(productKey));
    expect(out.center.dx, closeTo(rect.center.dx, 1e-6));
    expect(out.center.dy, closeTo(rect.center.dy, 1e-6));
    expect(out.width, closeTo(rect.width * 0.9, 1e-6));
  });

  testWidgets('degenerate params and boxes draw without errors', (
    tester,
  ) async {
    for (final params in <Map<String, Object?>>[
      {
        'insideScale': 0,
        'tilt': -1,
        'archWidth': 0,
        'shrinkTo': double.nan,
        'bubbles': -3,
        'bubbleArea': double.infinity,
        'scrimMaxPct': 900,
        'saturation': double.negativeInfinity,
      },
      {'archWidth': 99, 'bubbles': 1000, 'insideScale': 5},
      {'insideScale': 'x', 'tilt': null},
    ]) {
      for (final at in [rect, Rect.zero, const Rect.fromLTWH(10, 10, 0, 40)]) {
        for (final t in [double.nan, -1.0, 0.0, 0.3, 0.5, 0.9, 1.0, 2.0]) {
          await render(tester, input(params, at: at), t);
          expect(tester.takeException(), isNull, reason: '$params $at $t');
        }
      }
    }
  });

  test('reduced motion leaves the oven out: Swap then FlyToCart', () {
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 1800),
        StepSpec(step: 'Swap', weight: 300),
        StepSpec(step: 'FlyToCart', weight: 900),
      ]),
      registry: animSteps,
      total: const Duration(milliseconds: 3000),
      reduceMotion: true,
    );
    expect(plan.steps.map((s) => s.key), ['Swap', 'FlyToCart']);
    expect(plan.total, const Duration(milliseconds: 600));
  });

  Widget runner(List<AnimEvent> events) {
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 1800),
        StepSpec(step: 'Swap', weight: 300),
        StepSpec(step: 'FlyToCart', weight: 900),
      ]),
      registry: animSteps,
      total: const Duration(milliseconds: 3000),
      reduceMotion: false,
    );
    return MaterialApp(
      home: StepRunner(
        steps: plan.steps,
        total: plan.total,
        input: input(const {}),
        onEvent: events.add,
      ),
    );
  }

  testWidgets('a sequence with it completes and reports its lifecycle', (
    tester,
  ) async {
    final events = <AnimEvent>[];
    await tester.pumpWidget(runner(events));
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(events, [AnimEvent.started, AnimEvent.completed]);
  });

  testWidgets('leaving while it runs cancels cleanly', (tester) async {
    final events = <AnimEvent>[];
    await tester.pumpWidget(runner(events));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(events, [AnimEvent.started, AnimEvent.cancelled]);
    expect(tester.takeException(), isNull);
  });
}
