import 'package:animation/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-05..07: the crepe steps draw at every stage without touching state,
/// and folding keeps the right part of the disc.
void main() {
  const rect = Rect.fromLTWH(50, 100, 200, 200);
  AnimStepInput input([Map<String, Object?> params = const {}]) =>
      AnimStepInput(
        product: const ColoredBox(color: Color(0xFFFFCC88)),
        productRect: rect,
        cartTarget: const Offset(300, 20),
        params: params,
      );

  for (final (key, params) in [
    ('Griddle', <String, Object?>{}),
    ('Fold', <String, Object?>{'stage': 1}),
    ('Fold', <String, Object?>{'stage': 2}),
    ('Shrink', <String, Object?>{'folds': 1}),
    ('Swap', <String, Object?>{'folds': 1}),
    ('FlyToCart', <String, Object?>{'folds': 1}),
  ]) {
    testWidgets('$key $params draws from start to end', (tester) async {
      final step = animSteps[key]!;
      for (final t in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Builder(
              builder: (context) => step.build(
                context,
                AnimFrame(
                  t: t,
                  elapsed: Duration(milliseconds: (t * 800).round()),
                ),
                input(params),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull, reason: '$key at $t');
      }
    });
  }

  test('one fold keeps the bottom half, two keep the bottom-right quarter', () {
    const size = Size(100, 100);
    final half = const FoldClip(1).getClip(size).getBounds();
    expect(half.top, closeTo(50, 0.5));
    expect(half.width, closeTo(100, 0.5));
    final quarter = const FoldClip(2).getClip(size).getBounds();
    expect(quarter.left, closeTo(50, 0.5));
    expect(quarter.top, closeTo(50, 0.5));
  });

  test('the crepe steps are registered', () {
    expect(
      animationStepKeys,
      containsAll(['Griddle', 'Fold', 'Shrink', 'Swap', 'FlyToCart']),
    );
  });
}
