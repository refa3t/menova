import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Box: the baked product is lowered into its box and the lid closes; later
/// steps carrying the same `box` param show the closed box. Display only.
void main() {
  const rect = Rect.fromLTWH(40, 300, 320, 320);
  const productKey = Key('product');
  const box = {
    'size': 1.04,
    'color': '#C8975E',
    'print': '#A8322A',
    'text': 'Menova',
    'hinge': 'top',
    'openDeg': 105,
    'fit': 0.92,
  };
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
    baseScale: 0.82,
  );

  Future<void> render(
    WidgetTester tester,
    String step,
    AnimStepInput input,
    double t,
  ) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Builder(
        builder: (context) => animSteps[step]!.build(
          context,
          AnimFrame(
            t: t,
            elapsed: Duration(milliseconds: t.isFinite ? (t * 900).round() : 0),
          ),
          input,
        ),
      ),
    ),
  );

  test('the step is registered and its spec read from params', () {
    expect(animSteps['Box'], isA<BoxStep>());
    final spec = BoxSpec.from(box)!;
    expect(spec.color, const Color(0xFFC8975E));
    expect(spec.text, 'Menova');
    expect(BoxSpec.from({'hinge': 'up', 'text': 3})!.hinge, 'top');
    expect(BoxSpec.from({'text': 3})!.text, '');
    expect(BoxSpec.from(null), isNull);
  });

  testWidgets('the product goes in, then the lid closes over it', (
    tester,
  ) async {
    await render(tester, 'Box', input(const {'box': box}), 0);
    expect(find.byKey(productKey), findsOneWidget, reason: 'still out');
    await render(tester, 'Box', input(const {'box': box}), 0.4);
    expect(find.byKey(productKey), findsOneWidget, reason: 'in the box');
    expect(tester.widget<Boxed>(find.byType(Boxed)).lid, 1);
    await render(tester, 'Box', input(const {'box': box}), 0.65);
    final lid = tester.widget<Boxed>(find.byType(Boxed)).lid;
    expect(lid, inExclusiveRange(0, 1));
    await render(tester, 'Box', input(const {'box': box}), 1);
    expect(tester.widget<Boxed>(find.byType(Boxed)).lid, 0);
    expect(find.byKey(productKey), findsNothing, reason: 'closed in');
  });

  testWidgets('reduced motion shows the box closed at once', (tester) async {
    for (final t in [0.0, 0.5, 1.0]) {
      await render(
        tester,
        'Box',
        input(const {'box': box}, reduceMotion: true),
        t,
      );
      expect(tester.widget<Boxed>(find.byType(Boxed)).lid, 0);
    }
  });

  testWidgets('Swap and FlyToCart show the closed box', (tester) async {
    for (final step in ['Swap', 'FlyToCart']) {
      await render(tester, step, input(const {'box': box}), 0.5);
      expect(tester.widget<Boxed>(find.byType(Boxed)).lid, 0, reason: step);
      expect(find.byKey(productKey), findsNothing);
    }
    // Without the param: the baked product as before (crepe, tortilla).
    await render(tester, 'Swap', input(const {}), 0.5);
    expect(find.byType(Boxed), findsNothing);
    expect(find.byKey(productKey), findsOneWidget);
  });

  testWidgets('every hinge and degenerate params draw without errors', (
    tester,
  ) async {
    for (final params in <Map<String, Object?>>[
      for (final hinge in ['top', 'bottom', 'left', 'right'])
        {
          'box': {...box, 'hinge': hinge},
        },
      {
        'box': {
          'size': double.nan,
          'openDeg': -40,
          'fit': double.infinity,
          'color': 'brown',
          'text': '',
        },
        'scale': double.nan,
        'scrimMaxPct': 500,
      },
      {
        'box': {'size': 0, 'openDeg': 900},
      },
      {'box': 'x'},
    ]) {
      for (final at in [rect, Rect.zero]) {
        for (final t in [double.nan, -1.0, 0.0, 0.3, 0.6, 1.0, 2.0]) {
          await render(tester, 'Box', input(params, at: at), t);
          expect(tester.takeException(), isNull, reason: '$params $at $t');
        }
      }
    }
  });

  test('reduced motion leaves Box out: Swap then FlyToCart', () {
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 1900),
        StepSpec(step: 'Box', weight: 900),
        StepSpec(step: 'Swap', weight: 250),
        StepSpec(step: 'FlyToCart', weight: 800),
      ]),
      registry: animSteps,
      total: const Duration(milliseconds: 3850),
      reduceMotion: true,
    );
    expect(plan.steps.map((s) => s.key), ['Swap', 'FlyToCart']);
  });

  testWidgets('a sequence with it completes, or cancels cleanly', (
    tester,
  ) async {
    Widget runner(List<AnimEvent> events) {
      final plan = planSequence(
        sequence: const StepSequence([
          StepSpec(step: 'SlideIntoOven', weight: 1900),
          StepSpec(step: 'Box', weight: 900, params: {'box': box}),
          StepSpec(step: 'Swap', weight: 250, params: {'box': box}),
          StepSpec(step: 'FlyToCart', weight: 800, params: {'box': box}),
        ]),
        registry: animSteps,
        total: const Duration(milliseconds: 3850),
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

    final done = <AnimEvent>[];
    await tester.pumpWidget(runner(done));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, [AnimEvent.started, AnimEvent.completed]);

    await tester.pumpWidget(const SizedBox());
    final left = <AnimEvent>[];
    await tester.pumpWidget(runner(left));
    await tester.pump(const Duration(milliseconds: 2300));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(left, [AnimEvent.started, AnimEvent.cancelled]);
    expect(tester.takeException(), isNull);
  });
}
