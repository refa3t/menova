import 'dart:math';
import 'dart:ui' as ui;

import 'package:animation/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The finished wrap (P2-06/07) as the steps after the folds draw it:
/// clips are kept between frames, the pieces' shadow skips their baking, the
/// last fold does not build the wrap while it is unseen, a frame drawn after
/// others equals a fresh render, and a degenerate opening draws without NaN.
void main() {
  const lines = [
    [0.5, 0.75, 0.13, 0.26],
    [0.87, 0.26, 0.5, 0.75],
  ];
  const opening = {
    'ellipse': [0.5, 0.37, 0.285, 0.095],
    'contents': [0.16, 0.415, 0.84, 0.685],
    'frame': [0.16, 0.18, 0.86, 0.77],
    'sleeve': '#9C7650',
  };
  const backUrl = 'https://test.invalid/back.webp';
  const surfaceUrl = 'https://test.invalid/surface.webp';
  const rect = Rect.fromLTWH(40, 40, 280, 280);
  final capture = GlobalKey();

  ui.Image draw(void Function(Canvas c) paint) {
    final recorder = ui.PictureRecorder();
    paint(Canvas(recorder));
    final picture = recorder.endRecording();
    final image = picture.toImageSync(256, 256);
    picture.dispose();
    return image;
  }

  final product = draw((c) {
    c.drawCircle(
      const Offset(128, 128),
      120,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(110, 100), 150, const [
          Color(0xFFF3D9A4),
          Color(0xFFC98F45),
        ]),
    );
    for (var i = 0; i < 12; i++) {
      final r = 80 * (i % 3 + 1) / 3;
      c.drawCircle(
        Offset(128 + r * cos(i * 0.9), 128 + r * sin(i * 0.9)),
        6 + i % 4 * 2.0,
        Paint()..color = const Color(0xAA8B5A2B),
      );
    }
  });
  final back = draw((c) {
    c.drawCircle(
      const Offset(128, 128),
      122,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(140, 150), 160, const [
          Color(0xFFE2B878),
          Color(0xFF9A6230),
        ]),
    );
    for (var i = 0; i < 20; i++) {
      final r = 100 * (i % 4 + 1) / 4;
      c.drawCircle(
        Offset(128 + r * cos(i * 1.3), 128 + r * sin(i * 1.3)),
        3 + i % 3 * 2.0,
        Paint()..color = const Color(0x996B3A12),
      );
    }
  });
  final pieces = draw((c) {
    const colors = [
      Color(0xFFB71C1C),
      Color(0xFF33691E),
      Color(0xCCFFEB3B),
      Color(0xFF6D4C41),
      Color(0x99FFFFFF),
    ];
    for (var i = 0; i < 18; i++) {
      c.save();
      c.translate(50 + (i * 37) % 160.0, 112 + (i * 23) % 58.0);
      c.rotate(i * 0.7);
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 18 + i % 5 * 4.0,
          height: 10 + i % 3 * 5.0,
        ),
        Paint()..color = colors[i % colors.length],
      );
      c.restore();
    }
  });
  final surface = draw(
    (c) => c.drawRect(
      const Rect.fromLTWH(0, 0, 256, 256),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          const Offset(256, 256),
          const [Color(0xFF3A3A3A), Color(0xFF5A5045)],
        ),
    ),
  );

  final productWidget = RawImage(image: product, fit: BoxFit.contain);
  final contentsWidget = Transform.scale(
    scale: 0.9,
    child: RawImage(image: pieces, fit: BoxFit.contain),
  );

  void cacheNetworkImages() {
    for (final (url, image) in [(backUrl, back), (surfaceUrl, surface)]) {
      PaintingBinding.instance.imageCache.putIfAbsent(
        NetworkImage(url),
        () => OneFrameImageStreamCompleter(
          SynchronousFuture(ImageInfo(image: image.clone())),
        ),
      );
    }
  }

  Map<String, Object?> params(String step, {bool withOpening = true}) => {
    if (step.startsWith('Fold')) 'stage': step == 'Fold1' ? 1 : 2,
    if (!step.startsWith('Fold')) 'folds': 2,
    'lines': lines,
    if (withOpening) 'opening': opening,
    if (step == 'Shrink') ...{'shrinkTo': 0.85, 'scrimMaxPct': 0},
    if (step == 'FlyToCart') ...{
      'shrinkTo': 0.2,
      'arcControlPct': 20,
      'rotateDeg': -12,
    },
  };

  Widget stepAt(
    String step,
    Map<String, Object?> p,
    double t, {
    bool withContents = true,
    bool reduceMotion = false,
  }) {
    final key = step.startsWith('Fold') ? 'Fold' : step;
    return Builder(
      builder: (context) => animSteps[key]!.build(
        context,
        AnimFrame(
          t: t,
          elapsed: Duration(milliseconds: (t * 600).round()),
        ),
        AnimStepInput(
          product: productWidget,
          contents: withContents ? contentsWidget : null,
          productRect: rect,
          cartTarget: const Offset(340, 20),
          params: p,
          images: {
            if (key == 'Fold') 'surface': [surfaceUrl],
            'back': [backUrl],
          },
          reduceMotion: reduceMotion,
        ),
      ),
    );
  }

  Future<Uint8List> render(WidgetTester tester, Widget scene) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(
            key: capture,
            child: SizedBox.square(
              dimension: 360,
              child: ColoredBox(color: const Color(0xFFDDD5C8), child: scene),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final boundary =
        capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    return bytes!;
  }

  List<CustomClipper<Path>?> clippers(WidgetTester tester) => [
    for (final r in tester.renderObjectList<RenderClipPath>(
      find.descendant(of: find.byType(Folded), matching: find.byType(ClipPath)),
    ))
      r.clipper,
  ];

  testWidgets('a frame drawn after others equals a fresh render', (
    tester,
  ) async {
    for (final step in ['Swap', 'Shrink', 'FlyToCart']) {
      cacheNetworkImages();
      final p = params(step);
      await render(tester, stepAt(step, p, 0));
      final before = clippers(tester);
      final warm = await render(tester, stepAt(step, p, 0.6));
      // Same inputs: every clip of the wrap is kept, not computed again.
      final after = clippers(tester);
      expect(after, hasLength(before.length), reason: step);
      expect(after, isNotEmpty);
      for (var i = 0; i < after.length; i++) {
        expect(after[i]!.shouldReclip(before[i]!), isFalse, reason: step);
      }
      await tester.pumpWidget(const SizedBox());
      final cold = await render(tester, stepAt(step, p, 0.6));
      expect(warm, cold, reason: step);
    }
  });

  testWidgets('the pieces shadow is drawn from them unbaked', (tester) async {
    cacheNetworkImages();
    await render(tester, stepAt('Swap', params('Swap'), 1));
    final shadow = find.byWidgetPredicate(
      (w) =>
          w is ImageFiltered &&
          w.imageFilter == ui.ImageFilter.blur(sigmaX: 2, sigmaY: 2),
    );
    expect(shadow, findsOneWidget);
    expect(
      find.descendant(of: shadow, matching: find.byType(Cooked)),
      findsNothing,
    );
    expect(
      find.descendant(of: shadow, matching: find.byWidget(contentsWidget)),
      findsOneWidget,
    );
    // The bed and both layers of the heap stay baked.
    expect(
      find.ancestor(
        of: find.byWidget(contentsWidget),
        matching: find.byType(Cooked),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('the last fold builds the finished wrap only once seen', (
    tester,
  ) async {
    cacheNetworkImages();
    final p = params('Fold2');
    final finished = find.byWidgetPredicate(
      (w) => w is Folded && w.opening != null,
    );
    await render(tester, stepAt('Fold2', p, 0.5));
    expect(finished, findsNothing);
    await render(tester, stepAt('Fold2', p, 0.9));
    expect(finished, findsOneWidget);
  });

  testWidgets('a degenerate opening draws without NaN', (tester) async {
    cacheNetworkImages();
    for (final bad in [
      {
        ...opening,
        'ellipse': [0.5, 0.37, 0.285, 0],
      },
      {
        ...opening,
        'contents': [0.5, 0.415, 0.5, 0.685],
      },
      {
        ...opening,
        'contents': [0.16, 0.5, 0.84, 0.5],
      },
      {
        ...opening,
        'frame': [0.5, 0.5, 0.5, 0.5],
      },
    ]) {
      for (final step in ['Fold2', 'Swap', 'FlyToCart']) {
        final p = {...params(step), 'opening': bad};
        for (final t in [0.3, 0.9]) {
          await render(tester, stepAt(step, p, t));
        }
      }
    }
  });
}
