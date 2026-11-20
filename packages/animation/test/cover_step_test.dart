import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cover: a film is pulled over the baked product and stays on it through
/// the later steps that carry the same `cover` param; display only.
void main() {
  const rect = Rect.fromLTWH(60, 260, 220, 220);
  const productKey = Key('product');
  const cover = {
    'area': 0.9,
    'color': '#E8F2FA',
    'opacity': 0.16,
    'gloss': 0.75,
    'from': 'left',
  };
  const melt = {'area': 0.72};
  AnimStepInput input(
    Map<String, Object?> params, {
    Rect at = rect,
    bool reduceMotion = false,
  }) => AnimStepInput(
    product: const SizedBox.expand(key: productKey),
    contents: const SizedBox.expand(),
    productRect: at,
    cartTarget: const Offset(320, 20),
    params: params,
    reduceMotion: reduceMotion,
    baseScale: 0.84,
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
            elapsed: Duration(milliseconds: t.isFinite ? (t * 600).round() : 0),
          ),
          input,
        ),
      ),
    ),
  );

  test('the step is registered and its spec read from params', () {
    expect(animSteps['Cover'], isA<CoverStep>());
    final spec = CoverSpec.from(cover)!;
    expect(spec.color, const Color(0xFFE8F2FA));
    expect(spec.direction, const Offset(1, 0));
    expect(CoverSpec.from({'from': 'nowhere'})!.side, 'left');
    expect(CoverSpec.from('x'), isNull);
    expect(MeltSpec.from({'color': 'red'})!.color, const Color(0xFFF0B648));
  });

  for (final reduceMotion in [false, true]) {
    testWidgets('the film is pulled across (reduce motion $reduceMotion)', (
      tester,
    ) async {
      for (var i = 0; i <= 10; i++) {
        final t = i / 10;
        await render(
          tester,
          'Cover',
          input(const {
            'cover': cover,
            'melt': melt,
          }, reduceMotion: reduceMotion),
          t,
        );
        expect(tester.takeException(), isNull);
        final covered = tester.widget<Covered>(find.byType(Covered));
        if (reduceMotion || t == 1) expect(covered.progress, 1);
        if (!reduceMotion && t == 0) expect(covered.progress, 0);
        expect(find.byType(Melted), findsOneWidget);
      }
    });
  }

  testWidgets('Swap and FlyToCart keep the product melted and covered', (
    tester,
  ) async {
    for (final step in ['Swap', 'FlyToCart']) {
      await render(
        tester,
        step,
        input(const {'cover': cover, 'melt': melt}),
        0.5,
      );
      expect(tester.widget<Covered>(find.byType(Covered)).progress, 1);
      expect(find.byType(Melted), findsOneWidget);
    }
    // Without the params: the product as before (pizza, crepe).
    await render(tester, 'Swap', input(const {}), 0.5);
    expect(find.byType(Covered), findsNothing);
    expect(find.byType(Melted), findsNothing);
  });

  testWidgets('degenerate params and boxes draw without errors', (
    tester,
  ) async {
    for (final params in <Map<String, Object?>>[
      {
        'cover': {
          'area': double.nan,
          'opacity': -1,
          'gloss': double.infinity,
          'from': 3,
        },
        'melt': {'area': -2, 'blur': double.nan, 'sink': 9},
        'scale': double.nan,
        'scrimMaxPct': -5,
      },
      {
        'cover': {'area': 0},
        'melt': {'area': 0},
      },
      {'cover': 'x', 'melt': 1},
    ]) {
      for (final at in [rect, Rect.zero]) {
        for (final t in [double.nan, -1.0, 0.0, 0.5, 1.0, 3.0]) {
          for (final step in ['Cover', 'Swap', 'FlyToCart']) {
            // The runner only gives t in [0, 1]; Cover also takes others.
            if (step != 'Cover' && !(t >= 0 && t <= 1)) continue;
            await render(tester, step, input(params, at: at), t);
            expect(tester.takeException(), isNull, reason: '$step $params');
          }
        }
      }
    }
  });

  test('reduced motion leaves Cover out', () {
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 2000),
        StepSpec(step: 'Cover', weight: 600),
        StepSpec(step: 'Swap', weight: 300),
        StepSpec(step: 'FlyToCart', weight: 900),
      ]),
      registry: animSteps,
      total: const Duration(milliseconds: 3800),
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
          StepSpec(step: 'SlideIntoOven', weight: 2000, params: {'melt': melt}),
          StepSpec(
            step: 'Cover',
            weight: 600,
            params: {'melt': melt, 'cover': cover},
          ),
          StepSpec(
            step: 'Swap',
            weight: 300,
            params: {'melt': melt, 'cover': cover},
          ),
          StepSpec(
            step: 'FlyToCart',
            weight: 900,
            params: {'melt': melt, 'cover': cover},
          ),
        ]),
        registry: animSteps,
        total: const Duration(milliseconds: 3800),
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
