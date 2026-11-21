import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:animation/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// The tortilla's filling through its side folds and its roll, drawn: the
/// folding sides and the rolling part cover it (nothing of it is drawn on
/// them), it stays in sight on the part still flat and at the log's open
/// end, and the roll flows into Swap without a jump.
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
  const backUrl = 'https://test.invalid/tortilla_back.webp';
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

  // The filling: a strip across the lower middle (box 0.25..0.75 by
  // 0.475..0.675, as the tortilla's), in [colors].
  void Function(Canvas c) piecesIn(List<Color> colors) => (c) {
    for (var i = 0; i < 26; i++) {
      c.save();
      c.translate(70 + (i * 37) % 116.0, 126 + (i * 23) % 42.0);
      c.rotate(i * 0.7);
      c.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 14 + i % 4 * 3.0,
          height: 9 + i % 3 * 3.0,
        ),
        Paint()..color = colors[i % colors.length],
      );
      c.restore();
    }
  };

  void tortilla(Canvas c) {
    c.drawCircle(
      const Offset(128, 128),
      124,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(115, 110), 150, const [
          Color(0xFFF1DDB0),
          Color(0xFFD9B57A),
        ]),
    );
    for (var i = 0; i < 16; i++) {
      final r = 100 * (i % 4 + 1) / 4;
      c.drawCircle(
        Offset(128 + r * cos(i * 1.1), 128 + r * sin(i * 1.1)),
        3 + i % 3 * 2.0,
        Paint()..color = const Color(0x55A0682E),
      );
    }
  }

  const food = [
    Color(0xFFB71C1C),
    Color(0xFF33691E),
    Color(0xFFF2C94C),
    Color(0xFF8D5A3B),
    Color(0xFFEFEFE6),
  ];
  const blueOnly = [Color(0xFF1E3CFF)];

  ({Widget product, Widget contents}) scene(List<Color> colors) {
    final pieces = draw(piecesIn(colors));
    final product = draw((c) {
      tortilla(c);
      c.drawImage(pieces, Offset.zero, Paint());
    });
    return (
      product: RawImage(image: product, fit: BoxFit.contain),
      contents: RawImage(image: pieces, fit: BoxFit.contain),
    );
  }

  final foodScene = scene(food);
  final blueScene = scene(blueOnly);

  final back = draw((c) {
    c.drawCircle(
      const Offset(128, 128),
      124,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(140, 150), 160, const [
          Color(0xFFE8C88E),
          Color(0xFFB98446),
        ]),
    );
    for (var i = 0; i < 24; i++) {
      final r = 110 * (i % 4 + 1) / 4;
      c.drawCircle(
        Offset(128 + r * cos(i * 1.3), 128 + r * sin(i * 1.3)),
        4 + i % 3 * 2.0,
        Paint()..color = const Color(0x886B3A12),
      );
    }
  });
  final magenta = draw(
    (c) => c.drawCircle(
      const Offset(128, 128),
      124,
      Paint()..color = const Color(0xFFE020D0),
    ),
  );
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

  // As in definitions/tortilla.json.
  Map<String, Object?> params(String step) => switch (step) {
    'Fold1' => {'stage': 1, 'lines': sides, 'volume': 0, 'pieces': true},
    'Fold2' => {'stage': 2, 'lines': sides, 'volume': 0, 'pieces': true},
    'Roll' => {'folds': 2, 'lines': sides, 'roll': served, 'pieces': true},
    _ => {'folds': 2, 'lines': sides, 'roll': served},
  };

  Widget stepAt(
    String step,
    double t, {
    ({Widget product, Widget contents})? of,
    Widget? contents,
    String backOf = backUrl,
    bool reduceMotion = false,
  }) {
    final key = step.startsWith('Fold') ? 'Fold' : step;
    final s = of ?? foodScene;
    return Builder(
      builder: (context) => animSteps[key]!.build(
        context,
        AnimFrame(
          t: t,
          elapsed: Duration(milliseconds: (t * 1000).round()),
        ),
        AnimStepInput(
          product: s.product,
          contents: contents ?? s.contents,
          productRect: rect,
          cartTarget: const Offset(340, 20),
          params: params(step),
          images: {
            if (key != 'Swap') 'surface': [surfaceUrl],
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

  /// Share of the scene's pixels showing the (blue) filling.
  double blueShare(Uint8List rgba) {
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

  // Frames across the folds, the roll and Swap, as a contact sheet.
  // flutter test test/roll_render_test.dart --plain-name 'contact sheet'
  //   --dart-define=CONTACT_SHEET=<file.png>
  const sheet = String.fromEnvironment('CONTACT_SHEET');
  testWidgets('contact sheet', skip: sheet.isEmpty, (tester) async {
    cacheNetworkImages();
    const tFold = [0.0, 0.25, 0.5, 0.75, 1.0];
    const tRoll = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0];
    final rows = [
      [
        for (final t in tFold) await snapshot(tester, stepAt('Fold1', t)),
        for (final t in tFold) await snapshot(tester, stepAt('Fold2', t)),
      ],
      [for (final t in tRoll) await snapshot(tester, stepAt('Roll', t))],
      [
        for (final t in [0.0, 0.2, 0.5, 1.0])
          await snapshot(tester, stepAt('Swap', t)),
      ],
    ];
    const cell = 180.0;
    final cols = rows.map((r) => r.length).reduce(max);
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
        (cols * (cell + 4)).round(),
        (rows.length * (cell + 4)).round(),
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File(sheet).writeAsBytesSync(png!);
  });

  testWidgets('the filling stays in sight through the folds and the roll', (
    tester,
  ) async {
    cacheNetworkImages();
    final least = <String, double>{};
    for (final (step, frames) in [('Fold1', 20), ('Fold2', 20), ('Roll', 40)]) {
      for (var f = 0; f <= frames; f++) {
        final shown = blueShare(
          await render(tester, stepAt(step, f / frames, of: blueScene)),
        );
        // On the part still flat, then at the log's open end: never gone.
        expect(shown, greaterThan(0.001), reason: '$step at ${f / frames}');
        least[step] = min(least[step] ?? 1, shown);
      }
    }
    debugPrint(
      'filling in sight, at least (% of the scene): '
      '${least.map((k, v) => MapEntry(k, (v * 100).toStringAsFixed(2)))}',
    );
  });

  testWidgets('the folding sides and the rolling part cover the filling', (
    tester,
  ) async {
    cacheNetworkImages();
    // The back (the sides' and the log's outside) in a colour nothing else
    // has; the filling drawn or not over it must not change it.
    bool isBack(Uint8List px, int i) =>
        px[i] > px[i + 1] + 60 && px[i + 2] > px[i + 1] + 60;
    var checked = 0;
    for (final (step, frames) in [('Fold1', 8), ('Fold2', 8), ('Roll', 20)]) {
      for (var f = 0; f <= frames; f++) {
        Future<Uint8List> at(Widget contents) => render(
          tester,
          stepAt(
            step,
            f / frames,
            of: blueScene,
            contents: contents,
            backOf: magentaUrl,
          ),
        );
        final bare = await at(const SizedBox());
        final full = await at(blueScene.contents);
        var over = 0, back = 0;
        for (var i = 0; i < bare.length; i += 4) {
          if (!isBack(bare, i)) continue;
          back++;
          var d = 0;
          for (var c = 0; c < 3; c++) {
            d = max(d, (bare[i + c] - full[i + c]).abs());
          }
          if (d > 3) over++;
        }
        checked += back;
        expect(
          over,
          // (its anti-aliased edges aside)
          lessThanOrEqualTo(max(4, back ~/ 200)),
          reason: '$step at ${f / frames}: $over of $back',
        );
      }
    }
    expect(checked, greaterThan(10000));
  });

  testWidgets('the folds flow into the roll and the roll into Swap', (
    tester,
  ) async {
    cacheNetworkImages();
    final foldEnd = await render(tester, stepAt('Fold2', 1));
    // Every frame of the roll at 60 fps (1 s), then Swap's first frame.
    final frames = [
      for (var f = 0; f <= 60; f++)
        await render(tester, stepAt('Roll', f / 60)),
      await render(tester, stepAt('Swap', 0)),
    ];
    var most = 0.0;
    for (var i = 1; i < frames.length - 1; i++) {
      most = max(most, change(frames[i - 1], frames[i]));
    }
    final into = change(foldEnd, frames.first);
    final handover = change(frames[frames.length - 2], frames.last);
    debugPrint(
      'fold to roll ${into.toStringAsFixed(3)}/255, largest frame-to-frame '
      'change ${most.toStringAsFixed(2)}/255, roll to Swap '
      '${handover.toStringAsFixed(3)}/255',
    );
    // The roll starts with the filling where the folds left it.
    expect(into, lessThan(1));
    // No frame jumps.
    expect(most, lessThan(6));
    // The roll ends on the frame Swap begins with.
    expect(handover, lessThan(0.5));
  });

  testWidgets('the rolling sheet and the served log are captured once', (
    tester,
  ) async {
    cacheNetworkImages();
    // Its pieces count their paints: they are drawn only into the sheet's
    // image, so each paint is a capture.
    final counter = _PaintCounter();
    final pieces = Stack(
      fit: StackFit.expand,
      children: [
        foodScene.contents,
        CustomPaint(painter: counter),
      ],
    );
    for (var f = 0; f <= 30; f++) {
      await render(tester, stepAt('Roll', f / 30, contents: pieces));
    }
    expect(counter.paints, lessThanOrEqualTo(2));
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
