import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// One frame of a running step.
class AnimFrame {
  const AnimFrame({required this.t, required this.elapsed});

  /// Step progress in [0, 1].
  final double t;

  /// Wall time since the step started (for looping effects such as flames).
  final Duration elapsed;
}

/// What a step receives from the orchestrator. Display data only: the
/// engine never reads prices, the selection or the cart (ARC-05).
class AnimStepInput {
  const AnimStepInput({
    required this.product,
    required this.productRect,
    this.cartTarget,
    this.params = const {},
    this.images = const {},
    this.reduceMotion = false,
  });

  /// The customer's product as drawn when "add" was pressed (snapshot).
  final Widget product;

  /// Where the product sits on screen, in the overlay's coordinates.
  final Rect productRect;

  /// Centre of the cart icon, in the overlay's coordinates.
  final Offset? cartTarget;

  /// Step parameters from the category definition.
  final Map<String, Object?> params;

  /// Image URLs resolved from asset data by the orchestrator, by role
  /// (e.g. `hearth`, `fireBack` frames). Never hard-coded names.
  final Map<String, List<String>> images;

  final bool reduceMotion;
}

/// Extension point (P1-B07): one reusable unit of motion. A step draws the
/// whole overlay frame for its progress; it never changes app state.
abstract interface class AnimStep {
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input);
}

/// Maps a parent progress [t] to a sub-interval [begin, end] → [0, 1].
double interval(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.linear,
]) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}

/// The product looking baked by [amount] in [0, 1]: more saturated, warmer
/// and a little darker, with the crust browning from the edge inward and a
/// soft bubbling shimmer while cooking. Identity at 0.
class Cooked extends StatelessWidget {
  const Cooked({
    super.key,
    required this.amount,
    required this.child,
    this.saturation = 1.45,
    this.bubble = 0,
  });

  final double amount;
  final Widget child;

  /// Saturation reached when fully baked.
  final double saturation;

  /// Bubbling phase in [0, 1) (0 = still).
  final double bubble;

  @override
  Widget build(BuildContext context) {
    final a = amount.clamp(0.0, 1.0);
    if (a == 0) return child;
    // Both tints are drawn atop the product's own pixels only (srcATop), so
    // a product that does not fill its box (a half-moon crepe) gets no ring
    // in the empty space around it.
    Widget tinted = ShaderMask(
      blendMode: BlendMode.srcATop,
      // Crust browning: a warm brown ring that creeps inward.
      shaderCallback: (bounds) => RadialGradient(
        colors: [
          const Color(0x00000000),
          const Color(0x00000000),
          const Color(0xFF6B3410).withValues(alpha: 0.45 * a),
          const Color(0x00000000),
        ],
        stops: [0, 0.80 - 0.06 * a, 0.92, 1],
      ).createShader(bounds),
      child: ColorFiltered(
        colorFilter: cookedFilter(a, saturation),
        child: child,
      ),
    );
    if (bubble > 0) {
      // Bubbling: a faint warm shimmer drifting over the top.
      tinted = ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) => RadialGradient(
          center: Alignment(0.35 * _wave(bubble), 0.35 * _wave(bubble + 0.25)),
          radius: 0.55,
          colors: [
            const Color(0xFFFFE0A0).withValues(alpha: 0.18 * a),
            const Color(0x00FFE0A0),
          ],
        ).createShader(bounds),
        child: tinted,
      );
    }
    return tinted;
  }

  static double _wave(double x) => (x * 2 % 2 - 1).abs() * 2 - 1;
}

/// Saturation boost, warm shift (R up, B down) and slight darkening, lerped
/// from identity by [a]. Matrix form keeps transparent edges untouched.
ColorFilter cookedFilter(double a, double saturation) {
  final s = 1 + (saturation - 1) * a;
  // Luminance weights (Rec. 709).
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  final warmR = 1 + 0.08 * a, warmB = 1 - 0.14 * a, dark = 1 - 0.10 * a;
  return ColorFilter.matrix([
    (sr + s) * warmR * dark, sg * warmR * dark, sb * warmR * dark, 0, 0, //
    sr * dark, (sg + s) * dark, sb * dark, 0, 0, //
    sr * warmB * dark, sg * warmB * dark, (sb + s) * warmB * dark, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

/// A straight fold line across the product, in fractions of its box (0..1).
/// The part on the side where `cross(b - a, p - a) < 0` folds over (for a
/// horizontal line from left to right, that is the part above it).
class FoldLine {
  const FoldLine(this.a, this.b);

  final Offset a;
  final Offset b;

  /// From a step param `lines`: `[[x1, y1, x2, y2], ...]`.
  static List<FoldLine> listFrom(Object? raw) => [
    if (raw is List)
      for (final l in raw)
        if (l is List && l.length == 4)
          FoldLine(
            Offset((l[0] as num).toDouble(), (l[1] as num).toDouble()),
            Offset((l[2] as num).toDouble(), (l[3] as num).toDouble()),
          ),
  ];

  Offset _at(Size s, Offset f) => Offset(f.dx * s.width, f.dy * s.height);

  /// The folding side of the line, as a large polygon in box pixels.
  Path foldingSide(Size size) {
    final pa = _at(size, a), pb = _at(size, b);
    final d = pb - pa;
    final u = d / d.distance;
    // Left normal in screen coordinates (y down): cross < 0 side.
    final n = Offset(u.dy, -u.dx);
    final far = size.longestSide * 4;
    return Path()..addPolygon([
      pa - u * far,
      pb + u * far,
      pb + u * far + n * far,
      pa - u * far + n * far,
    ], true);
  }

  /// The mirror image across the line: where the folded part lands.
  Matrix4 reflection(Size size) {
    final pa = _at(size, a);
    final d = _at(size, b) - pa;
    final u = d / d.distance;
    final m00 = 2 * u.dx * u.dx - 1, m01 = 2 * u.dx * u.dy;
    final m11 = 2 * u.dy * u.dy - 1;
    final tx = pa.dx - (m00 * pa.dx + m01 * pa.dy);
    final ty = pa.dy - (m01 * pa.dx + m11 * pa.dy);
    return Matrix4(m00, m01, 0, 0, m01, m11, 0, 0, 0, 0, 1, 0, tx, ty, 0, 1);
  }

  /// A turn of [angle] about the line, in 3D with [perspective]; at pi it
  /// equals [reflection] (the fold is complete).
  Matrix4 turn(Size size, double angle, double perspective) {
    final pa = _at(size, a);
    final d = _at(size, b) - pa;
    final phi = atan2(d.dy, d.dx);
    final c = size.center(Offset.zero);
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..setEntry(3, 2, perspective)
      ..translateByDouble(pa.dx - c.dx, pa.dy - c.dy, 0, 1)
      ..rotateZ(phi)
      ..rotateX(angle)
      ..rotateZ(-phi)
      ..translateByDouble(-pa.dx, -pa.dy, 0, 1);
  }
}

class _PathClip extends CustomClipper<Path> {
  const _PathClip(this.build);

  final Path Function(Size size) build;

  @override
  Path getClip(Size size) => build(size);

  @override
  bool shouldReclip(_PathClip oldClipper) => true;
}

/// The area of the box no earlier fold took away.
Path _unfolded(Size size, List<FoldLine> lines) {
  var keep = Path()..addRect(Offset.zero & size);
  for (final l in lines) {
    keep = Path.combine(PathOperation.difference, keep, l.foldingSide(size));
  }
  return keep;
}

/// A product folded along the first [count] of [lines], seen from above
/// (P2-06): each fold lifts the part on its folding side and lays it,
/// mirrored, over the rest. The outside of a folded crepe is its back, so a
/// folded part shows [back] (same shape as the product) when given.
class Folded extends StatelessWidget {
  const Folded({
    super.key,
    required this.lines,
    required this.count,
    required this.product,
    this.back,
    this.without,
    this.reveal = const [],
  });

  final List<FoldLine> lines;
  final int count;
  final Widget product;
  final Widget? back;

  /// The open end of a wrap (polygon, fractions of the box): once every line
  /// is folded, the inside shows there over the folds, like the filling at
  /// the top of a crepe cone.
  final List<Offset> reveal;

  /// A line whose folding side is left out (the part folding right now).
  final FoldLine? without;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(0, lines.length);
    if (n == 0 && without == null) return product;
    final done = lines.take(n).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        Path keep(Size s) {
          final p = _unfolded(s, done);
          final w = without;
          return w == null
              ? p
              : Path.combine(PathOperation.difference, p, w.foldingSide(s));
        }

        final layers = Stack(
          fit: StackFit.expand,
          children: [
            ClipPath(clipper: _PathClip(keep), child: product),
            for (var i = 0; i < done.length; i++)
              Transform(
                transform: done[i].reflection(size),
                child: ClipPath(
                  clipper: _PathClip(
                    (s) => Path.combine(
                      PathOperation.intersect,
                      _unfolded(s, done.take(i).toList()),
                      done[i].foldingSide(s),
                    ),
                  ),
                  child: back ?? product,
                ),
              ),
          ],
        );
        if (n < lines.length || without != null) return layers;

        // Fully folded: the wrap keeps the outline of what was not folded
        // (folded parts tuck in, no corners stick out) and gets volume.
        final core = ClipPath(
          clipper: _PathClip((s) => _unfolded(s, done)),
          child: layers,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            // Soft shadow under the wrap, so it lifts off the surface.
            Transform.translate(
              offset: Offset(0, size.height * 0.025),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                child: ColorFiltered(
                  colorFilter: const ColorFilter.mode(
                    Color(0x66000000),
                    BlendMode.srcIn,
                  ),
                  child: core,
                ),
              ),
            ),
            // A rounded surface: darker at both sides, light in the middle.
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (b) => const LinearGradient(
                colors: [
                  Color(0x99000000),
                  Color(0x22000000),
                  Color(0x33FFFFFF),
                  Color(0x22000000),
                  Color(0xA0000000),
                ],
                stops: [0.25, 0.38, 0.5, 0.62, 0.75],
              ).createShader(b),
              child: core,
            ),
            // The folded edges: a lit crease with a soft shadow beside it.
            IgnorePointer(child: CustomPaint(painter: _CreasePainter(done))),
            if (reveal.length >= 3) _Opening(product: product, reveal: reveal),
          ],
        );
      },
    );
  }
}

/// The open end of a wrap: the inside shows a little proud of the folds
/// (the filling pushes out) and darkens with depth.
class _Opening extends StatelessWidget {
  const _Opening({required this.product, required this.reveal});

  final Widget product;
  final List<Offset> reveal;

  @override
  Widget build(BuildContext context) {
    final ys = reveal.map((p) => p.dy);
    final xs = reveal.map((p) => p.dx);
    final top = ys.reduce(min), bottom = ys.reduce(max);
    final cx = (xs.reduce(min) + xs.reduce(max)) / 2;
    return ClipPath(
      clipper: revealClip(reveal),
      child: ShaderMask(
        blendMode: BlendMode.srcATop,
        // Deeper into the wrap is darker.
        shaderCallback: (b) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [
            Color(0x00000000),
            Color(0x00000000),
            Color(0x66000000),
          ],
          stops: [0, top + (bottom - top) * 0.45, bottom],
        ).createShader(b),
        child: Transform.scale(
          scale: 1.06,
          alignment: Alignment(cx * 2 - 1, bottom * 2 - 1),
          child: product,
        ),
      ),
    );
  }
}

/// Lit creases along fold lines, drawn only inside the folded wrap.
class _CreasePainter extends CustomPainter {
  const _CreasePainter(this.lines);

  final List<FoldLine> lines;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipPath(_unfolded(size, lines));
    final shadow = Paint()
      ..color = const Color(0x40000000)
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final light = Paint()
      ..color = const Color(0x8CFFF2DA)
      ..strokeWidth = 2;
    for (final l in lines) {
      final a = Offset(l.a.dx * size.width, l.a.dy * size.height);
      final b = Offset(l.b.dx * size.width, l.b.dy * size.height);
      final d = (b - a) / (b - a).distance;
      // Shadow just inside the fold, on the side that stays.
      final n = Offset(-d.dy, d.dx) * 4;
      // Only the lower part of the segment: the upper end is the open end
      // of the wrap, where no crease shows.
      final low = a.dy > b.dy ? a : b, high = a.dy > b.dy ? b : a;
      final end = Offset.lerp(low, high, 0.7)!;
      canvas.drawLine(low + n, end + n, shadow);
      canvas.drawLine(low, end, light);
    }
  }

  @override
  bool shouldRepaint(_CreasePainter oldDelegate) => oldDelegate.lines != lines;
}

/// Clips to a polygon given in fractions of the box.
CustomClipper<Path> revealClip(List<Offset> points) => _PathClip(
  (s) => Path()
    ..addPolygon([
      for (final p in points) Offset(p.dx * s.width, p.dy * s.height),
    ], true),
);

/// A polygon from a step param `reveal`: `[[x, y], ...]` (fractions).
List<Offset> revealFrom(Object? raw) => [
  if (raw is List)
    for (final p in raw)
      if (p is List && p.length == 2)
        Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
];

/// The back image a step was given (role `back`), if any.
Widget? backImage(AnimStepInput input) {
  final url = input.images['back']?.firstOrNull;
  if (url == null) return null;
  return Image.network(
    url,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// The product as the sequence has shaped it so far: baked and flat, or
/// folded along the first `folds` of its fold `lines` (step params), the
/// folded parts showing the back.
Widget shapedProduct(AnimStepInput input) {
  final folds = (input.params['folds'] as num?)?.toInt() ?? 0;
  final baked = Cooked(amount: 1, child: input.product);
  if (folds <= 0) return baked;
  return Folded(
    lines: FoldLine.listFrom(input.params['lines']),
    count: folds,
    product: baked,
    back: backImage(input),
    reveal: revealFrom(input.params['reveal']),
  );
}

/// The cooking surface (role `surface`) under the product, slightly larger.
Widget? surfaceUnder(AnimStepInput input, {double opacity = 1}) {
  final url = input.images['surface']?.firstOrNull;
  if (url == null || opacity <= 0) return null;
  return Positioned.fromRect(
    rect: Rect.fromCenter(
      center: input.productRect.center,
      width: input.productRect.width * 1.16,
      height: input.productRect.height * 1.16,
    ),
    child: Image.network(
      url,
      fit: BoxFit.contain,
      opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}
