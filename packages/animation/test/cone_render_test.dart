import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:animation/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The finished wrap (P2-06/07) as the steps after the folds draw it:
/// clips are kept between frames, the wrap is painted once into its own
/// layer and only the transforms around it change, that layer looks like the
/// wrap painted afresh (anti-aliasing aside), the pieces' shadow skips their
/// baking, the last fold does not build the wrap while it is unseen, and a
/// degenerate opening draws without NaN.
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
  const magentaUrl = 'https://test.invalid/back_magenta.webp';
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

  // The filling's pieces; the product (the whole canvas) shows them too.
  void drawPieces(Canvas c) {
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
    // The pieces as the product shows them (scaled like [contentsWidget]).
    c
      ..save()
      ..translate(128, 128)
      ..scale(0.9)
      ..translate(-128, -128);
    drawPieces(c);
    c.restore();
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
  final pieces = draw(drawPieces);
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

  // A back (the folded sides' outside) in a colour nothing else has.
  final magenta = draw(
    (c) => c.drawCircle(
      const Offset(128, 128),
      122,
      Paint()..color = const Color(0xFFE020D0),
    ),
  );

  final productWidget = RawImage(image: product, fit: BoxFit.contain);
  final contentsWidget = Transform.scale(
    scale: 0.9,
    child: RawImage(image: pieces, fit: BoxFit.contain),
  );

  void cacheNetworkImages() {
    for (final (url, image) in [
      (backUrl, back),
      (surfaceUrl, surface),
      (magentaUrl, magenta),
    ]) {
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
    Widget? product,
    Widget? contents,
    String backOf = backUrl,
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
          product: product ?? productWidget,
          contents: withContents ? contents ?? contentsWidget : null,
          productRect: rect,
          cartTarget: const Offset(340, 20),
          params: p,
          images: {
            if (key == 'Fold') 'surface': [surfaceUrl],
            'back': [backOf],
          },
          reduceMotion: reduceMotion,
        ),
      ),
    );
  }

  Future<ui.Image> snapshot(WidgetTester tester, Widget scene) async {
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
    return (await tester.runAsync(boundary.toImage))!;
  }

  Future<Uint8List> render(WidgetTester tester, Widget scene) async {
    final image = await snapshot(tester, scene);
    final bytes = await tester.runAsync(() async {
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

  testWidgets('the wrap in its own layer looks like it painted afresh', (
    tester,
  ) async {
    addTearDown(() => debugWrapOwnLayer = true);
    var worst = 0, worstShare = 0.0;
    for (final (step, t) in [
      ('Fold2', 0.9),
      ('Fold2', 1.0),
      ('Swap', 0.0),
      ('Swap', 0.5),
      ('Swap', 1.0),
      ('Shrink', 0.5),
      ('Shrink', 1.0),
      ('FlyToCart', 0.3),
      ('FlyToCart', 0.6),
      ('FlyToCart', 0.9),
    ]) {
      cacheNetworkImages();
      final p = params(step);
      debugWrapOwnLayer = true;
      await tester.pumpWidget(const SizedBox());
      await render(tester, stepAt(step, p, 0));
      final layered = await render(tester, stepAt(step, p, t));
      debugWrapOwnLayer = false;
      await tester.pumpWidget(const SizedBox());
      final afresh = await render(tester, stepAt(step, p, t));
      expect(layered, hasLength(afresh.length));
      var most = 0, pixels = 0;
      for (var i = 0; i < afresh.length; i += 4) {
        var px = 0;
        for (var c = 0; c < 4; c++) {
          px = max(px, (layered[i + c] - afresh[i + c]).abs());
        }
        if (px > 0) pixels++;
        most = max(most, px);
      }
      final share = pixels / (afresh.length / 4);
      // Only the rim's thin lines anti-alias a little differently.
      expect(most, lessThanOrEqualTo(24), reason: '$step at $t');
      expect(share, lessThanOrEqualTo(0.01), reason: '$step at $t');
      worst = max(worst, most);
      worstShare = max(worstShare, share);
    }
    debugPrint(
      'wrap layer vs afresh: max diff $worst/255, '
      'at most ${(worstShare * 100).toStringAsFixed(3)}% of pixels',
    );
  });

  testWidgets('the wrap is painted once while the steps move it', (
    tester,
  ) async {
    addTearDown(() => debugWrapOwnLayer = true);
    for (final layered in [true, false]) {
      debugWrapOwnLayer = layered;
      final counter = _PaintCounter();
      final counted = Stack(
        fit: StackFit.expand,
        children: [
          contentsWidget,
          CustomPaint(painter: counter),
        ],
      );
      for (final step in ['Swap', 'Shrink', 'FlyToCart']) {
        cacheNetworkImages();
        final p = params(step);
        Widget at(double t) => Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(
            builder: (context) => animSteps[step]!.build(
              context,
              AnimFrame(
                t: t,
                elapsed: Duration(milliseconds: (t * 600).round()),
              ),
              AnimStepInput(
                product: productWidget,
                contents: counted,
                productRect: rect,
                cartTarget: const Offset(340, 20),
                params: p,
                images: const {
                  'back': [backUrl],
                },
              ),
            ),
          ),
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(at(0));
        expect(tester.takeException(), isNull);
        final first = counter.paints;
        expect(first, greaterThan(0), reason: step);
        for (final t in [0.2, 0.4, 0.6, 0.8, 1.0]) {
          await tester.pumpWidget(at(t));
        }
        if (layered) {
          // Every later frame reuses the layer: nothing inside is painted.
          expect(counter.paints, first, reason: step);
        } else {
          // Painted afresh, the pieces are painted again each frame.
          expect(counter.paints, greaterThan(first), reason: step);
        }
      }
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

  // The filling in one colour no crepe has (blue), in the product too.
  void drawBlue(Canvas c) {
    for (var i = 0; i < 18; i++) {
      c.drawOval(
        Rect.fromCenter(
          center: Offset(50 + (i * 37) % 160.0, 112 + (i * 23) % 58.0),
          width: 22,
          height: 14,
        ),
        Paint()..color = const Color(0xFF1E3CFF),
      );
    }
  }

  final blue = draw(drawBlue);
  final blueProduct = draw((c) {
    c.drawImage(product, Offset.zero, Paint());
    c
      ..save()
      ..translate(128, 128)
      ..scale(0.9)
      ..translate(-128, -128);
    drawBlue(c);
    c.restore();
  });
  final blueScene = (
    product: RawImage(image: blueProduct, fit: BoxFit.contain),
    contents: Transform.scale(
      scale: 0.9,
      child: RawImage(image: blue, fit: BoxFit.contain),
    ),
  );

  /// Share of the scene's pixels showing the (blue) filling.
  double filling(Uint8List rgba) {
    var n = 0;
    for (var i = 0; i < rgba.length; i += 4) {
      final r = rgba[i], g = rgba[i + 1], b = rgba[i + 2];
      if (b > r + 60 && b > g + 40) n++;
    }
    return n / (rgba.length / 4);
  }

  /// Mean difference per channel (0..255) between two frames.
  double change(Uint8List a, Uint8List b) {
    var sum = 0;
    for (var i = 0; i < a.length; i++) {
      sum += (a[i] - b[i]).abs();
    }
    return sum / a.length;
  }

  testWidgets('the filling stays in sight while the sides fold', (
    tester,
  ) async {
    cacheNetworkImages();
    var least = 1.0;
    for (final step in ['Fold1', 'Fold2']) {
      for (var ms = 0; ms <= 650; ms += 25) {
        final shown = filling(
          await render(
            tester,
            stepAt(
              step,
              params(step),
              ms / 650,
              product: blueScene.product,
              contents: blueScene.contents,
            ),
          ),
        );
        // Gathered into the uncovered middle, then heaped up in the open
        // end: never all gone under the sides.
        expect(shown, greaterThan(0.002), reason: '$step at $ms ms');
        least = min(least, shown);
      }
    }
    debugPrint(
      'filling in sight: at least ${(least * 100).toStringAsFixed(2)}% '
      'of the scene',
    );
  });

  testWidgets('the folded sides cover the filling', (tester) async {
    cacheNetworkImages();
    bool isBack(Uint8List px, int i) =>
        px[i] > px[i + 1] + 60 && px[i + 2] > px[i + 1] + 60;
    // Below the open end, where the pile comes up over the sides as the
    // wrap closes (rows above the rim's middle).
    final rimRow = (rect.top + 0.37 * rect.height).ceil();
    for (final step in ['Fold1', 'Fold2']) {
      // Until the finished wrap takes over.
      for (var ms = 0; ms <= 420; ms += 30) {
        Future<Uint8List> at(Widget contents) => render(
          tester,
          stepAt(
            step,
            params(step),
            ms / 650,
            product: blueScene.product,
            contents: contents,
            backOf: magentaUrl,
          ),
        );
        final bare = await at(const SizedBox());
        final full = await at(blueScene.contents);
        var over = 0, sides = 0;
        for (var i = rimRow * 360 * 4; i < bare.length; i += 4) {
          if (!isBack(bare, i)) continue;
          sides++;
          var d = 0;
          for (var c = 0; c < 3; c++) {
            d = max(d, (bare[i + c] - full[i + c]).abs());
          }
          if (d > 3) over++;
        }
        // Nothing of the filling is drawn on a folded side.
        expect(
          over,
          // (its anti-aliased edges aside)
          lessThanOrEqualTo(max(4, sides ~/ 200)),
          reason: '$step $ms ms: $over of $sides',
        );
      }
    }
  });

  testWidgets('the fold flows into the finished wrap and into Swap', (
    tester,
  ) async {
    cacheNetworkImages();
    // Every frame at 60 fps over the last fold, then Swap's first frame.
    final frames = [
      for (var f = 0; f <= 39; f++)
        await render(tester, stepAt('Fold2', params('Fold2'), f / 39)),
      await render(tester, stepAt('Swap', params('Swap'), 0)),
    ];
    var most = 0.0;
    for (var i = 1; i < frames.length; i++) {
      most = max(most, change(frames[i - 1], frames[i]));
    }
    final handover = change(frames[frames.length - 2], frames.last);
    debugPrint(
      'largest frame-to-frame change ${most.toStringAsFixed(2)}/255, '
      'last fold to Swap ${handover.toStringAsFixed(3)}/255',
    );
    // No frame jumps: each is a small step from the one before (the
    // finished wrap used to appear at once, 36/255 between two frames).
    expect(most, lessThan(6));
    // The last fold ends on the frame Swap begins with.
    expect(handover, lessThan(0.5));
  });

  // Frames across both folds (every 100 ms of 650 ms) and the first Swap
  // frames, as a contact sheet: rows Fold 1, Fold 2, Swap.
  // flutter test test/cone_render_test.dart --plain-name 'contact sheet'
  //   --dart-define=CONTACT_SHEET=<file.png>
  const sheet = String.fromEnvironment('CONTACT_SHEET');
  testWidgets('contact sheet', skip: sheet.isEmpty, (tester) async {
    cacheNetworkImages();
    const ms = [0, 100, 200, 300, 400, 500, 600, 650];
    final rows = [
      for (final step in ['Fold1', 'Fold2'])
        [
          for (final m in ms)
            await snapshot(tester, stepAt(step, params(step), m / 650)),
        ],
      [
        for (final m in [0, 50, 100, 150, 200, 300])
          await snapshot(tester, stepAt('Swap', params('Swap'), m / 300)),
      ],
    ];
    const cell = 180.0;
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    c.drawPaint(Paint()..color = const Color(0xFFFFFFFF));
    for (var r = 0; r < rows.length; r++) {
      for (var i = 0; i < rows[r].length; i++) {
        final im = rows[r][i];
        c.drawImageRect(
          im,
          Offset.zero & Size(im.width.toDouble(), im.height.toDouble()),
          Rect.fromLTWH(i * (cell + 4), r * (cell + 4), cell, cell),
          Paint()..filterQuality = FilterQuality.medium,
        );
      }
    }
    final picture = recorder.endRecording();
    final png = await tester.runAsync(() async {
      final image = await picture.toImage(
        (ms.length * (cell + 4)).round(),
        (rows.length * (cell + 4)).round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(sheet).writeAsBytesSync(png!);
  });
}

/// Counts how often it is painted; never asks to repaint itself.
class _PaintCounter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(_PaintCounter oldDelegate) => false;
}
