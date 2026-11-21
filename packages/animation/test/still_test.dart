import 'dart:ui' as ui;

import 'package:animation/animation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// [Still]: its child is painted once and kept as an image while only what
/// is around it changes, and captured again when the child changes.
void main() {
  final capture = GlobalKey();

  Future<Color> centre(WidgetTester tester, Widget child, double angle) async {
    await tester.pumpWidget(
      Center(
        child: RepaintBoundary(
          key: capture,
          child: SizedBox.square(
            dimension: 40,
            child: Transform.rotate(angle: angle, child: Still(child: child)),
          ),
        ),
      ),
    );
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final data = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return bytes!;
    });
    final i = (20 * 40 + 20) * 4;
    final px = data!.buffer.asUint8List();
    return Color.fromARGB(px[i + 3], px[i], px[i + 1], px[i + 2]);
  }

  testWidgets('painted once while it moves, again when it changes', (
    tester,
  ) async {
    final counter = _Counter(const Color(0xFF2040E0));
    await centre(tester, CustomPaint(painter: counter), 0);
    final first = counter.paints;
    expect(first, greaterThan(0));
    for (final a in [0.1, 0.2, 0.3]) {
      await centre(tester, CustomPaint(painter: counter), a);
    }
    expect(counter.paints, first);

    final red = _Counter(const Color(0xFFE02020));
    final shown = await centre(tester, CustomPaint(painter: red), 0.3);
    expect(red.paints, greaterThan(0));
    expect(shown.r, greaterThan(0.8));
    expect(shown.b, lessThan(0.3));
  });

  testWidgets('drawn under the transforms around it', (tester) async {
    for (final m in [
      Matrix4.diagonal3Values(1, 0.05, 1),
      Matrix4.identity()..rotateX(1.5),
    ]) {
      await tester.pumpWidget(
        Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: capture,
            child: SizedBox.square(
              dimension: 40,
              child: Transform(
                transform: m,
                child: const Opacity(
                  opacity: 0.5,
                  child: Still(child: ColoredBox(color: Color(0xFFE02020))),
                ),
              ),
            ),
          ),
        ),
      );
      final boundary =
          capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final data = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!;
      });
      final px = data!.buffer.asUint8List();
      // Squashed to the top: nothing near the bottom.
      final i = (35 * 40 + 20) * 4;
      expect(px[i + 3], 0, reason: '$m');
    }
  });
}

class _Counter extends CustomPainter {
  _Counter(this.color);

  final Color color;
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) {
    paints++;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Counter oldDelegate) => oldDelegate.color != color;
}
