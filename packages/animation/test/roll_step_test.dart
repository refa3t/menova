import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Roll step (a wrap rolled up into a log) and the steps after it: they
/// draw at every stage without touching state, honour reduced motion, and a
/// degenerate shape draws without NaN.
void main() {
  const sides = [
    [0.2, 1, 0.2, 0],
    [0.8, 0, 0.8, 1],
  ];
  const roll = {
    'area': [0.2, 0.03, 0.8, 0.97],
    'thickness': 0.2,
    'log': [0.08, 0.36, 0.92, 0.64],
    'contents': [0.25, 0.475, 0.75, 0.675],
  };
  const served = {...roll, 'sleeve': '#D9CCB0'};
  const rect = Rect.fromLTWH(40, 80, 240, 240);

  AnimStepInput input(
    Map<String, Object?> params, {
    bool reduceMotion = false,
  }) => AnimStepInput(
    product: const ColoredBox(color: Color(0xFFF0DDB0)),
    productRect: rect,
    cartTarget: const Offset(300, 20),
    params: params,
    reduceMotion: reduceMotion,
  );

  Future<void> drawAll(
    WidgetTester tester,
    String key,
    Map<String, Object?> params, {
    bool reduceMotion = false,
  }) async {
    for (final t in [0.0, 0.1, 0.2, 0.5, 0.86, 0.95, 1.0]) {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => animSteps[key]!.build(
              context,
              AnimFrame(
                t: t,
                elapsed: Duration(milliseconds: (t * 1000).round()),
              ),
              input(params, reduceMotion: reduceMotion),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: '$key $params at $t');
    }
  }

  test('Roll is registered', () {
    expect(animSteps['Roll'], isA<RollStep>());
    expect(animationStepKeys, contains('Roll'));
  });

  for (final (key, params) in [
    ('Roll', <String, Object?>{'folds': 2, 'lines': sides, 'roll': roll}),
    ('Roll', <String, Object?>{'roll': roll}),
    ('Roll', <String, Object?>{'folds': 2, 'lines': sides}),
    ('Fold', <String, Object?>{'stage': 2, 'lines': sides, 'volume': 0}),
    ('Swap', <String, Object?>{'folds': 2, 'lines': sides, 'roll': served}),
    ('Shrink', <String, Object?>{'folds': 2, 'lines': sides, 'roll': served}),
    ('FlyToCart', <String, Object?>{'roll': served}),
  ]) {
    testWidgets('$key $params draws from start to end', (tester) async {
      await drawAll(tester, key, params);
      await drawAll(tester, key, params, reduceMotion: true);
    });
  }

  testWidgets('the roll ends as the served log, before its paper', (
    tester,
  ) async {
    Future<RolledLog> logAt(String key, Map<String, Object?> p) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => animSteps[key]!.build(
              context,
              const AnimFrame(t: 1, elapsed: Duration(seconds: 1)),
              input(p),
            ),
          ),
        ),
      );
      return tester.widget<RolledLog>(find.byType(RolledLog));
    }

    final rolled = await logAt('Roll', {'roll': served});
    final swapped = await logAt('Swap', {'roll': served});
    expect(rolled.rect.left, closeTo(swapped.rect.left, 1e-9));
    expect(rolled.rect.top, closeTo(swapped.rect.top, 1e-9));
    expect(rolled.rect.right, closeTo(swapped.rect.right, 1e-9));
    expect(rolled.rect.bottom, closeTo(swapped.rect.bottom, 1e-9));
    // Paper only once served.
    expect(rolled.sleeve, isNull);
    expect(swapped.sleeve, const Color(0xFFD9CCB0));
  });

  testWidgets('reduced motion shows the finished log at once', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (context) => animSteps['Roll']!.build(
            context,
            const AnimFrame(t: 0, elapsed: Duration.zero),
            input({'roll': roll}, reduceMotion: true),
          ),
        ),
      ),
    );
    final log = tester.widget<RolledLog>(find.byType(RolledLog));
    expect(log.rect.top, closeTo(0.36, 1e-9));
    expect(log.turn, 1);
  });

  testWidgets('a degenerate roll draws without NaN', (tester) async {
    for (final bad in <Map<String, Object?>>[
      {...roll, 'thickness': 0},
      {...roll, 'thickness': -1},
      {
        ...roll,
        'area': [0.5, 0.5, 0.5, 0.5],
      },
      {
        ...roll,
        'log': [0.5, 0.5, 0.5, 0.5],
      },
      {
        ...roll,
        'contents': [0.5, 0.5, 0.5, 0.5],
      },
      {
        ...roll,
        'area': [0.2, 0.9, 0.8, 0.1],
      },
    ]) {
      for (final key in ['Roll', 'Swap', 'FlyToCart']) {
        await drawAll(tester, key, {'folds': 2, 'lines': sides, 'roll': bad});
      }
    }
  });

  test('a roll shape is read from step params, its paper optional', () {
    final s = RollShape.from(served)!;
    expect(s.area, const Rect.fromLTRB(0.2, 0.03, 0.8, 0.97));
    expect(s.thickness, 0.2);
    expect(s.settled, const Rect.fromLTRB(0.08, 0.36, 0.92, 0.64));
    expect(s.sleeve, const Color(0xFFD9CCB0));
    expect(s.unwrapped.sleeve, isNull);
    expect(s.unwrapped.settled, s.settled);
    // Without `log` it rests where rolling leaves it: across the top.
    final plain = RollShape.from({'area': roll['area'], 'thickness': 0.2})!;
    expect(plain.settled.top, closeTo(0.03, 1e-9));
    expect(plain.settled.height, closeTo(0.2, 1e-9));
    expect(RollShape.from({...served, 'sleeve': 'kraft'})!.sleeve, isNull);
    expect(
      RollShape.from({
        'area': [0.1],
        'thickness': 0.2,
      }),
      isNull,
    );
    expect(RollShape.from({'area': roll['area']}), isNull);
    expect(RollShape.from('roll'), isNull);
  });

  test('reduced motion plays only Swap then FlyToCart of a wrap', () {
    const sequence = StepSequence([
      StepSpec(step: 'Griddle', weight: 800),
      StepSpec(step: 'Fold', weight: 450),
      StepSpec(step: 'Fold', weight: 450),
      StepSpec(step: 'Roll', weight: 1000),
      StepSpec(step: 'Swap', weight: 300),
      StepSpec(step: 'Shrink', weight: 300),
      StepSpec(step: 'FlyToCart', weight: 750),
    ]);
    final full = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: const Duration(milliseconds: 4050),
      reduceMotion: false,
    );
    expect(full.steps.map((s) => s.key), contains('Roll'));
    final reduced = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: const Duration(milliseconds: 4050),
      reduceMotion: true,
    );
    expect(reduced.steps.map((s) => s.key), ['Swap', 'FlyToCart']);
    expect(reduced.total, const Duration(milliseconds: 600));
  });

  testWidgets('leaving mid-roll cancels cleanly', (tester) async {
    final events = <AnimEvent>[];
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(
          step: 'Roll',
          weight: 1,
          params: {'folds': 2, 'lines': sides, 'roll': roll},
        ),
        StepSpec(step: 'Swap', weight: 1, params: {'roll': served}),
      ]),
      registry: animSteps,
      total: const Duration(milliseconds: 1000),
      reduceMotion: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StepRunner(
          steps: plan.steps,
          total: plan.total,
          input: input(const {}),
          onEvent: events.add,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(RolledLog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(events, [AnimEvent.started, AnimEvent.cancelled]);
  });
}
