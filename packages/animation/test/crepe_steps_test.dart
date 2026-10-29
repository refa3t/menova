import 'package:animation/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P2-05..07: the crepe steps draw at every stage without touching state,
/// and folding keeps the right part of the disc.
void main() {
  const cone = [
    [0.42, 0.78, 0.28, 0.2],
    [0.72, 0.2, 0.58, 0.78],
  ];
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
    ('Fold', <String, Object?>{'stage': 1, 'lines': cone}),
    ('Fold', <String, Object?>{'stage': 2, 'lines': cone}),
    ('Shrink', <String, Object?>{'folds': 2, 'lines': cone}),
    ('Swap', <String, Object?>{'folds': 2, 'lines': cone}),
    ('FlyToCart', <String, Object?>{'folds': 2, 'lines': cone}),
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

  test('a fold line mirrors its folding side across the line', () {
    const size = Size(100, 100);
    // Horizontal line through the middle: the top folds down.
    const half = FoldLine(Offset(0, 0.5), Offset(1, 0.5));
    expect(half.foldingSide(size).contains(const Offset(50, 20)), isTrue);
    expect(half.foldingSide(size).contains(const Offset(50, 80)), isFalse);
    final m = half.reflection(size);
    final landed = MatrixUtils.transformPoint(m, const Offset(30, 20));
    expect(landed.dx, closeTo(30, 1e-6));
    expect(landed.dy, closeTo(80, 1e-6));
    // A full turn about the line ends where the reflection does.
    final turned = MatrixUtils.transformPoint(
      half.turn(size, 3.141592653589793, 0),
      const Offset(30, 20),
    );
    expect(turned.dx, closeTo(30, 1e-6));
    expect(turned.dy, closeTo(80, 1e-6));
  });

  test('fold lines are read from step params', () {
    final lines = FoldLine.listFrom([
      [0.42, 0.78, 0.28, 0.2],
      [0.72, 0.2, 0.58, 0.78],
      'bad',
    ]);
    expect(lines, hasLength(2));
    expect(lines.first.a, const Offset(0.42, 0.78));
  });

  test('the crepe steps are registered', () {
    expect(
      animationStepKeys,
      containsAll(['Griddle', 'Fold', 'Shrink', 'Swap', 'FlyToCart']),
    );
  });
}
