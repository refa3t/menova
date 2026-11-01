import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const sequence = StepSequence([
  StepSpec(step: 'Oven', weight: 50),
  StepSpec(step: 'Swap', weight: 12),
  StepSpec(step: 'FlyToCart', weight: 38),
  StepSpec(step: 'Unknown', weight: 10),
]);

const input = AnimStepInput(
  product: SizedBox(key: Key('product'), width: 100, height: 100),
  productRect: Rect.fromLTWH(100, 100, 200, 200),
  cartTarget: Offset(20, 20),
);

void main() {
  test('plan: weights become shares, unknown steps are skipped', () {
    final plan = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: const Duration(milliseconds: 2000),
      reduceMotion: false,
    );
    expect(plan.steps.map((s) => s.key), ['Oven', 'Swap', 'FlyToCart']);
    expect(plan.steps.first.share, closeTo(0.5, 1e-9));
    expect(plan.total, const Duration(milliseconds: 2000));
  });

  test('plan: reduced motion keeps Swap then FlyToCart within 600ms', () {
    final plan = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: const Duration(milliseconds: 2000),
      reduceMotion: true,
    );
    expect(plan.steps.map((s) => s.key), ['Swap', 'FlyToCart']);
    expect(plan.total, const Duration(milliseconds: 600));
  });

  Widget runner(List<AnimEvent> events) {
    final plan = planSequence(
      sequence: sequence,
      registry: animSteps,
      total: const Duration(milliseconds: 2000),
      reduceMotion: false,
    );
    return MaterialApp(
      home: StepRunner(
        steps: plan.steps,
        total: plan.total,
        input: input,
        onEvent: events.add,
      ),
    );
  }

  testWidgets('runs to completion and reports lifecycle', (tester) async {
    final events = <AnimEvent>[];
    await tester.pumpWidget(runner(events));
    expect(events, [AnimEvent.started]);
    expect(find.byKey(const Key('product')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pump(const Duration(milliseconds: 1000));
    expect(events, [AnimEvent.started, AnimEvent.completed]);
  });

  testWidgets('tap skips to a short final step', (tester) async {
    final events = <AnimEvent>[];
    await tester.pumpWidget(runner(events));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byType(StepRunner));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(events, [AnimEvent.started, AnimEvent.skipped, AnimEvent.completed]);
  });

  testWidgets('leaving mid-animation cancels cleanly', (tester) async {
    final events = <AnimEvent>[];
    await tester.pumpWidget(runner(events));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(events, [AnimEvent.started, AnimEvent.cancelled]);
  });

  testWidgets('each step gets only the images it declares', (tester) async {
    final first = <Set<String>>[], second = <Set<String>>[];
    final plan = planSequence(
      sequence: const StepSequence([
        StepSpec(
          step: 'A',
          params: {
            'images': {'surface': 'griddle_surface'},
          },
        ),
        StepSpec(
          step: 'B',
          params: {
            'images': {'back': 'crepe_back'},
          },
        ),
      ]),
      registry: {'A': _Recorder(first), 'B': _Recorder(second)},
      total: const Duration(milliseconds: 1000),
      reduceMotion: false,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: StepRunner(
          steps: plan.steps,
          total: plan.total,
          input: const AnimStepInput(
            product: SizedBox(),
            productRect: Rect.zero,
            images: {
              'surface': ['surface.webp'],
              'back': ['back.webp'],
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(first.last, {'surface'});
    expect(second.last, {'back'}, reason: 'no surface under a later step');
  });
}

/// Records which image roles a step was given.
class _Recorder implements AnimStep {
  _Recorder(this.seen);

  final List<Set<String>> seen;

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    seen.add(input.images.keys.toSet());
    return const SizedBox.shrink();
  }
}
