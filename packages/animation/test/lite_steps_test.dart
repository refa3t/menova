import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The phone path (`AnimStepInput.lite`) of the pizza's and the cheese pan's
/// steps (SlideIntoOven, Box, Cover): no blur, colour filter or shader mask
/// is redrawn frame by frame (the baked look is one image), the box's faces
/// are images, and the result looks like the full path's.
void main() {
  const rect = Rect.fromLTWH(40, 60, 280, 280);
  const melt = {'area': 0.72, 'blur': 1.6, 'tint': 0.42, 'sink': 0.45};
  const cover = {'area': 0.9, 'opacity': 0.16, 'gloss': 0.75, 'from': 'left'};
  const box = {
    'size': 1.04,
    'text': 'Menova',
    'hinge': 'top',
    'openDeg': 105,
    'fit': 0.92,
  };
  // Shared by every frame, as the orchestrator's snapshot is.
  const product = CustomPaint(painter: _ProductPainter(false));
  const pieces = CustomPaint(painter: _ProductPainter(true));
  const capture = Key('capture');

  AnimStepInput input(Map<String, Object?> params, {bool lite = true}) =>
      AnimStepInput(
        product: product,
        contents: pieces,
        productRect: rect,
        cartTarget: const Offset(340, 10),
        params: params,
        baseScale: 0.84,
        lite: lite,
      );

  Widget scene(
    String step,
    AnimStepInput input,
    double t, {
    bool still = false,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: capture,
        child: SizedBox(
          width: 360,
          height: 400,
          child: ColoredBox(
            color: const Color(0xFFDDD5C8),
            child: Builder(
              builder: (context) => animSteps[step]!.build(
                context,
                AnimFrame(
                  t: t,
                  elapsed: Duration(
                    milliseconds: still ? 0 : (t * 2000).round(),
                  ),
                ),
                input,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  Future<Uint8List> pixels(WidgetTester tester) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(capture),
    );
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  bool underStill(WidgetTester tester, Finder f) =>
      find.ancestor(of: f, matching: find.byType(Still)).evaluate().isNotEmpty;

  testWidgets('the oven bakes and melts from one image, not every frame', (
    tester,
  ) async {
    for (var i = 0; i <= 20; i++) {
      final t = i / 20;
      await tester.pumpWidget(
        scene('SlideIntoOven', input(const {'melt': melt, 'bubbles': 12}), t),
      );
      expect(tester.takeException(), isNull);
      // Every effect there is drawn once inside an image, fully baked.
      for (final e in find.byType(Melted).evaluate()) {
        expect((e.widget as Melted).amount, 1, reason: 't $t');
        expect(underStill(tester, find.byWidget(e.widget)), isTrue);
      }
      for (final e in find.byType(Cooked).evaluate()) {
        expect((e.widget as Cooked).amount, 1, reason: 't $t');
        expect(underStill(tester, find.byWidget(e.widget)), isTrue);
      }
      // A path clip only inside that image (the melt's circle).
      for (final e in find.byType(ClipPath).evaluate()) {
        expect(underStill(tester, find.byWidget(e.widget)), isTrue);
      }
      // Baking: the raw product crossfades to that image.
      if (t > 0.35 && t < 0.65) expect(find.byType(LiteBaked), findsOneWidget);
    }
    // Without a melt: the product's own baked image (shared with Box).
    for (final t in [0.0, 0.5, 1.0]) {
      await tester.pumpWidget(scene('SlideIntoOven', input(const {}), t));
      for (final e in find.byType(Cooked).evaluate()) {
        final c = e.widget as Cooked;
        expect(c.lite || underStill(tester, find.byWidget(c)), isTrue);
      }
    }
    // The full path melts frame by frame.
    await tester.pumpWidget(
      scene('SlideIntoOven', input(const {'melt': melt}, lite: false), 0.4),
    );
    expect(find.byType(LiteBaked), findsNothing);
    final melting = tester.widget<Melted>(find.byType(Melted));
    expect(melting.amount, inExclusiveRange(0, 1));
  });

  testWidgets('the wall and the box are images, kept while they move', (
    tester,
  ) async {
    RenderObject wallAt(double t) {
      final stills = find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byType(Still),
      );
      expect(stills, findsOneWidget, reason: 't $t');
      return tester.renderObject(stills);
    }

    await tester.pumpWidget(scene('SlideIntoOven', input(const {}), 0.1));
    final wall = wallAt(0.1);
    await tester.pumpWidget(scene('SlideIntoOven', input(const {}), 0.5));
    expect(wallAt(0.5), same(wall));

    // The lid's outer side (shut past upright), by its key.
    RenderObject lidAt(double t) =>
        tester.renderObject(find.byKey(const ValueKey(false)));
    await tester.pumpWidget(scene('Box', input(const {'box': box}), 0.6));
    final lid = lidAt(0.6);
    expect(tester.widget<Boxed>(find.byType(Boxed)).lite, isTrue);
    await tester.pumpWidget(scene('Box', input(const {'box': box}), 0.62));
    expect(lidAt(0.62), same(lid));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the film is cut without a path and the product is one image', (
    tester,
  ) async {
    for (final t in [0.0, 0.3, 0.6, 1.0]) {
      await tester.pumpWidget(
        scene('Cover', input(const {'melt': melt, 'cover': cover}), t),
      );
      expect(tester.takeException(), isNull);
      expect(tester.widget<Covered>(find.byType(Covered)).lite, isTrue);
      expect(find.byType(LiteBaked), findsOneWidget);
    }
    // Shapes it does not draw itself are the full path's.
    await tester.pumpWidget(scene('Cover', input(const {'box': box}), 0.5));
    expect(find.byType(Boxed), findsOneWidget);
    expect(find.byType(LiteBaked), findsNothing);
  });

  testWidgets('it looks like the full path', (tester) async {
    for (final (step, params, t) in <(String, Map<String, Object?>, double)>[
      ('SlideIntoOven', const {}, 0.0),
      ('SlideIntoOven', const {}, 0.5),
      ('SlideIntoOven', const {}, 1.0),
      ('SlideIntoOven', const {'melt': melt}, 1.0),
      ('Cover', const {'melt': melt, 'cover': cover}, 0.5),
      ('Cover', const {'melt': melt, 'cover': cover}, 1.0),
      ('Box', const {'box': box}, 0.35),
      ('Box', const {'box': box}, 0.6),
      ('Box', const {'box': box}, 1.0),
    ]) {
      await tester.pumpWidget(const SizedBox());
      // At time 0: the full path's drifting shimmer and shine (left out on
      // a phone) at rest.
      await tester.pumpWidget(
        scene(step, input(params, lite: false), t, still: true),
      );
      final full = await pixels(tester);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(scene(step, input(params), t, still: true));
      final lite = await pixels(tester);
      expect(tester.takeException(), isNull);
      expect(lite, hasLength(full.length));
      var sum = 0, off = 0;
      for (var i = 0; i < full.length; i += 4) {
        var most = 0;
        for (var c = 0; c < 4; c++) {
          final d = (lite[i + c] - full[i + c]).abs();
          sum += d;
          most = max(most, d);
        }
        if (most > 24) off++;
      }
      final mean = sum / full.length;
      final share = off / (full.length / 4);
      expect(mean, lessThan(1.5), reason: '$step $params $t: mean $mean');
      expect(share, lessThan(0.02), reason: '$step $params $t: off $share');
    }
  });

  testWidgets('the cheese pan and pizza sequences run through on a phone', (
    tester,
  ) async {
    for (final sequence in [
      const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 2700, params: {'melt': melt}),
        StepSpec(
          step: 'Cover',
          weight: 800,
          params: {'melt': melt, 'cover': cover},
        ),
        StepSpec(
          step: 'Swap',
          weight: 300,
          params: {'melt': melt, 'cover': cover},
        ),
        StepSpec(
          step: 'FlyToCart',
          weight: 1000,
          params: {'melt': melt, 'cover': cover},
        ),
      ]),
      const StepSequence([
        StepSpec(step: 'SlideIntoOven', weight: 1900),
        StepSpec(step: 'Box', weight: 900, params: {'box': box}),
        StepSpec(step: 'Swap', weight: 250, params: {'box': box}),
        StepSpec(step: 'FlyToCart', weight: 800, params: {'box': box}),
      ]),
    ]) {
      final plan = planSequence(
        sequence: sequence,
        registry: animSteps,
        total: const Duration(milliseconds: 4800),
        reduceMotion: false,
      );
      final events = <AnimEvent>[];
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
      for (var i = 0; i < 50; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
      }
      expect(events, [AnimEvent.started, AnimEvent.completed]);
      await tester.pumpWidget(const SizedBox());
    }
  });
}

/// A product with colour and detail (a base and pieces), or its pieces
/// alone, so a blur, a tint or a resampling would show.
class _ProductPainter extends CustomPainter {
  const _ProductPainter(this.piecesOnly);

  final bool piecesOnly;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    if (!piecesOnly) {
      canvas.drawCircle(c, r * 0.95, Paint()..color = const Color(0xFFE0B070));
      canvas.drawCircle(c, r * 0.8, Paint()..color = const Color(0xFFC0392B));
    }
    final rng = Random(3);
    for (var i = 0; i < 24; i++) {
      final a = rng.nextDouble() * 2 * pi, d = sqrt(rng.nextDouble()) * r * 0.7;
      canvas.drawCircle(
        c + Offset(cos(a), sin(a)) * d,
        r * 0.06,
        Paint()..color = i.isEven ? const Color(0xFF2E7D32) : Colors.black87,
      );
    }
  }

  @override
  bool shouldRepaint(_ProductPainter old) => old.piecesOnly != piecesOnly;
}
