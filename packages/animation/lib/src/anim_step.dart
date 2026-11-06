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
    this.contents,
  });

  /// The customer's product as drawn when "add" was pressed (snapshot).
  final Widget product;

  /// The same snapshot's pieces alone (no base), same box, when the
  /// orchestrator could capture them: a wrap heaps its filling from them.
  final Widget? contents;

  /// Where the product sits on screen, in the overlay's coordinates.
  final Rect productRect;

  /// Centre of the cart icon, in the overlay's coordinates.
  final Offset? cartTarget;

  /// Step parameters from the category definition.
  final Map<String, Object?> params;

  /// Image URLs resolved from asset data by the orchestrator, by role
  /// (e.g. `hearth`, `fireBack` frames). Never hard-coded names. A running
  /// step gets only the roles its own `images` param declares.
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
    this.opening,
    this.zoom = 1,
    this.contents,
  });

  final List<FoldLine> lines;
  final int count;
  final Widget product;
  final Widget? back;

  /// The product's pieces alone, same box: a finished wrap heaps them in
  /// its opening (see [AnimStepInput.contents]).
  final Widget? contents;

  /// The open end of a wrap: once every line is folded, the product's
  /// contents show inside it, wrapped by the walls (a crepe cone).
  final WrapOpening? opening;

  /// A line whose folding side is left out (the part folding right now).
  final FoldLine? without;

  /// How far a finished wrap has grown into its `frame` (0 as folded, 1
  /// filling the box).
  final double zoom;

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
        if (opening case final o? when back != null) {
          return _WrapView(
            lines: done,
            opening: o,
            product: product,
            back: back!,
            zoom: zoom,
            contents: contents,
          );
        }

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
          ],
        );
      },
    );
  }
}

/// The open end of a wrap (step param `opening`, fractions of the box):
/// `ellipse` `[cx, cy, rx, ry]` is the rim at the top, `contents`
/// `[x0, y0, x1, y1]` the part of the product that fills it (the filling),
/// the optional `frame` `[x0, y0, x1, y1]` the wrap's bounds, which it grows
/// into to fill the box once finished, and the optional `sleeve`
/// (`#RRGGBB`) the colour of a paper cone it is served in.
class WrapOpening {
  const WrapOpening({
    required this.ellipse,
    required this.contents,
    this.frame,
    this.sleeve,
  });

  final Rect ellipse;
  final Rect contents;
  final Rect? frame;
  final Color? sleeve;

  /// The same wrap before it goes into its paper (still on the griddle).
  WrapOpening get unwrapped =>
      WrapOpening(ellipse: ellipse, contents: contents, frame: frame);

  static WrapOpening? from(Object? raw) {
    if (raw is! Map) return null;
    final e = raw['ellipse'], c = raw['contents'], f = raw['frame'];
    if (e is! List || e.length != 4 || c is! List || c.length != 4) {
      return null;
    }
    double n(Object? v) => (v as num).toDouble();
    final s = raw['sleeve'];
    return WrapOpening(
      ellipse: Rect.fromCenter(
        center: Offset(n(e[0]), n(e[1])),
        width: 2 * n(e[2]),
        height: 2 * n(e[3]),
      ),
      contents: Rect.fromLTRB(n(c[0]), n(c[1]), n(c[2]), n(c[3])),
      frame: f is List && f.length == 4
          ? Rect.fromLTRB(n(f[0]), n(f[1]), n(f[2]), n(f[3]))
          : null,
      sleeve: s is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)
          ? Color(0xFF000000 | int.parse(s.substring(1), radix: 16))
          : null,
    );
  }
}

/// A finished wrap with an open end, drawn to look real (owner reference
/// photo): the outside narrows from the rim to the point and is round (lit
/// from the left, in shade on the right), the rim is the crepe's thin edge,
/// and inside it the filling sits heaped below a strip of the inner wall.
/// An optional paper cone shows beside it.
class _WrapView extends StatelessWidget {
  const _WrapView({
    required this.lines,
    required this.opening,
    required this.product,
    required this.back,
    required this.zoom,
    this.contents,
  });

  final List<FoldLine> lines;
  final WrapOpening opening;
  final Widget product;
  final Widget back;
  final double zoom;
  final Widget? contents;

  /// The griddle side as the outside of a thin, lightly toasted crepe:
  /// paler and less yellow, with its browned spots kept.
  static const _toasted = ColorFilter.matrix([
    0.797, 0.275, 0.028, 0, -20, //
    0.082, 0.990, 0.028, 0, -20, //
    0.082, 0.275, 0.743, 0, -20, //
    0, 0, 0, 1, 0, //
  ]);

  /// Where the last two folds cross (the point of the cone); without two
  /// lines, the bottom of the frame.
  Offset _tip(Size size) {
    Offset at(Offset f) => Offset(f.dx * size.width, f.dy * size.height);
    if (lines.length >= 2) {
      final l1 = lines[lines.length - 2], l2 = lines.last;
      final p = at(l1.a), r = at(l1.b) - p;
      final q = at(l2.a), d = at(l2.b) - q;
      final den = r.dx * d.dy - r.dy * d.dx;
      if (den.abs() > 1e-9) {
        final t = ((q.dx - p.dx) * d.dy - (q.dy - p.dy) * d.dx) / den;
        return p + r * t;
      }
    }
    final f = opening.frame ?? opening.ellipse;
    return at(Offset(f.center.dx, f.bottom));
  }

  /// The two points where lines from [tip] touch [oval] (its outline as
  /// seen from the point).
  static (Offset, Offset) _tangents(Rect oval, Offset tip) {
    var left = oval.centerLeft, right = oval.centerRight;
    var minA = double.infinity, maxA = -double.infinity;
    for (var i = 0; i < 360; i++) {
      final th = i * pi / 180;
      final pt = Offset(
        oval.center.dx + oval.width / 2 * cos(th),
        oval.center.dy + oval.height / 2 * sin(th),
      );
      final a = atan2(pt.dx - tip.dx, tip.dy - pt.dy); // angle from vertical
      if (a < minA) (minA, left) = (a, pt);
      if (a > maxA) (maxA, right) = (a, pt);
    }
    return (left, right);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        Rect px(Rect r) => Rect.fromLTRB(
          r.left * size.width,
          r.top * size.height,
          r.right * size.width,
          r.bottom * size.height,
        );
        Alignment at(Offset p) =>
            Alignment(p.dx / size.width * 2 - 1, p.dy / size.height * 2 - 1);
        // Clockwise angle of [p] around the point, in [0, 2pi).
        double around(Offset p, Offset centre) {
          final a = atan2(p.dy - centre.dy, p.dx - centre.dx);
          return a < 0 ? a + 2 * pi : a;
        }

        final rim = px(opening.ellipse);
        final lip = size.width * 0.008; // the crepe's own thickness
        // Silhouette: the rim, and the walls running straight from the
        // rim's sides (tangent) down to the point where the folds meet.
        final tip = _tip(size);
        final edge = rim.inflate(lip);
        final (left, right) = _tangents(edge, tip);
        Path cone(Size s) => Path.combine(
          PathOperation.union,
          Path()..addOval(edge),
          Path()..addPolygon([tip, left, right], true),
        );

        // The paper cone: wider than the wrap and cut on a slant, so its
        // corners stand out beside the rim and its edges along the walls.
        final paper = opening.sleeve;
        final sleeve = [
          tip + Offset(0, lip * 2),
          Offset(
            edge.left - edge.width * 0.08,
            edge.center.dy + edge.height * 0.12,
          ),
          Offset(
            edge.right + edge.width * 0.11,
            edge.center.dy - edge.height * 0.1,
          ),
        ];
        Path outline(Size s) => paper == null
            ? cone(s)
            : Path.combine(
                PathOperation.union,
                cone(s),
                Path()..addPolygon(sleeve, true),
              );

        // The outside, round: shaded by its angle around the point (so the
        // shade follows the walls down to it), lit from the left.
        final body = ClipPath(
          clipper: _PathClip(cone),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: _toasted,
                child: Transform.scale(scale: 1.45, child: back),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: SweepGradient(
                    center: at(tip),
                    startAngle: around(left, tip),
                    endAngle: around(right, tip),
                    colors: const [
                      Color(0x59000000),
                      Color(0x0A000000),
                      Color(0x1FFFF3DC),
                      Color(0x00000000),
                      Color(0x47000000),
                      Color(0x80000000),
                    ],
                    stops: const [0, 0.1, 0.3, 0.52, 0.85, 1],
                  ),
                ),
              ),
              // A little darker where it is folded tight, near the point.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: const [
                      Color(0x00000000),
                      Color(0x00000000),
                      Color(0x38000000),
                    ],
                    stops: [
                      0,
                      (rim.bottom / size.height).clamp(0.0, 1.0),
                      (tip.dy / size.height).clamp(0.0, 1.0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

        // Inside the rim: a strip of the inner wall at the back, and the
        // filling below it, filling the opening to the front edge. When the
        // product's pieces come apart from it, they are heaped into a dome
        // that rises above the back of the rim, a second layer behind and
        // each piece shading what lies under it (owner: a full, 3D filling).
        final pieces = contents;
        final heap = Rect.fromLTRB(
          rim.left,
          rim.top + rim.height * 0.07,
          rim.right,
          rim.bottom + rim.height * 0.07,
        );
        final region = px(opening.contents);
        final target = Rect.fromLTRB(
          rim.left - rim.width * 0.03,
          heap.top - rim.height * 0.08,
          rim.right + rim.width * 0.03,
          rim.bottom + rim.height * 0.25,
        );
        final scale = target.width / region.width;
        // With the pieces apart, the filling is seen at the rim's tilt:
        // flattened in depth like the opening itself, centred a little
        // above the rim's middle, so only the pieces' ragged top edge rises
        // above the rim (a low heap, owner reference).
        final squash = pieces == null ? 1.0 : 0.55;
        final middle = pieces == null
            ? target.center
            : rim.center - Offset(0, rim.height * 0.1);
        // [child] (a widget of the product's box) with the filling region
        // fitted into the opening; [grow], [lift] and [flip] vary a layer.
        Widget fitted(
          Widget child, {
          double grow = 1,
          double lift = 0,
          bool flip = false,
        }) {
          final k = scale * grow;
          final c = middle - Offset(0, lift);
          return Transform(
            transform: Matrix4.identity()
              ..translateByDouble(c.dx, c.dy, 0, 1)
              ..scaleByDouble(flip ? -k : k, k * squash, 1, 1)
              ..translateByDouble(-region.center.dx, -region.center.dy, 0, 1),
            child: SizedBox.fromSize(size: size, child: child),
          );
        }

        // The inner wall: the crepe's cooked side, lit at the rim and in
        // shade where it goes down behind the filling.
        final wall = ClipPath(
          clipper: _PathClip((_) => Path()..addOval(rim)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: rim,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFDCC08E), Color(0xFFA27A4A)],
                      stops: [0, 0.25],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        final heapBounds = Rect.fromLTRB(
          rim.left,
          rim.top - rim.height * 0.4,
          rim.right,
          rim.bottom,
        );
        Path lensShape(Size s) => Path.combine(
          PathOperation.intersect,
          Path()..addOval(rim),
          Path()..addOval(heap),
        );
        // Room for the pile above the rim: wide enough that the pieces'
        // own outlines, not this shape, make the top of the heap.
        Path pileShape(Size s) => Path.combine(
          PathOperation.union,
          lensShape(s),
          // Above the rim's middle only (below it the walls hide the
          // pile); the pieces' own top edge ends it.
          Path.combine(
            PathOperation.intersect,
            // A mound: narrower towards the top, so its sides curve in.
            Path()..addOval(
              Rect.fromCenter(
                center: rim.center + Offset(0, rim.height * 0.2),
                width: rim.width * 0.98,
                height: rim.height * 2.2,
              ),
            ),
            Path()..addRect(
              Rect.fromLTRB(-s.width, -s.height, 2 * s.width, rim.center.dy),
            ),
          ),
        );
        final filling = Stack(
          fit: StackFit.expand,
          children: [
            // The bed of the filling, level with the opening.
            ClipPath(
              clipper: _PathClip(lensShape),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  fitted(product),
                  // Lit on top, falling away into shade at the sides, under
                  // the back wall and towards the front edge.
                  Positioned.fromRect(
                    rect: heap,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Color(0x4D000000),
                            Color(0x00000000),
                            Color(0x14FFFFFF),
                            Color(0x00000000),
                            Color(0x5C000000),
                          ],
                          stops: [0, 0.16, 0.4, 0.76, 1],
                        ),
                      ),
                    ),
                  ),
                  Positioned.fromRect(
                    rect: heap,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0x73000000),
                            Color(0x00000000),
                            Color(0x00000000),
                            Color(0x2E000000),
                          ],
                          stops: [0, 0.24, 0.8, 1],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (pieces != null)
              // The pile: a second, mirrored layer behind and higher in its
              // shade, each front piece's soft shadow, the front layer, and
              // light falling on the pieces themselves (a mound).
              ClipPath(
                clipper: _PathClip(pileShape),
                child: ShaderMask(
                  blendMode: BlendMode.srcATop,
                  shaderCallback: (_) => const RadialGradient(
                    center: Alignment(0, -0.3),
                    radius: 0.78,
                    colors: [
                      Color(0x29FFFFFF),
                      Color(0x00FFFFFF),
                      Color(0x00000000),
                      Color(0x61000000),
                    ],
                    stops: [0, 0.4, 0.68, 1],
                    transform: _StretchToBounds(),
                  ).createShader(heapBounds),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0x47000000),
                          BlendMode.srcATop,
                        ),
                        child: fitted(
                          pieces,
                          grow: 0.92,
                          lift: rim.height * 0.14,
                          flip: true,
                        ),
                      ),
                      Transform.translate(
                        offset: Offset(lip * 0.6, lip * 1.3),
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: 2,
                            sigmaY: 2,
                          ),
                          child: ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              Color(0x8C000000),
                              BlendMode.srcIn,
                            ),
                            child: fitted(pieces),
                          ),
                        ),
                      ),
                      fitted(pieces),
                    ],
                  ),
                ),
              ),
          ],
        );

        final wrap = Stack(
          fit: StackFit.expand,
          children: [
            // Soft contact shadow under the wrap.
            Transform.translate(
              offset: Offset(size.width * 0.015, size.height * 0.03),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: ClipPath(
                  clipper: _PathClip(outline),
                  child: const ColoredBox(color: Color(0x66000000)),
                ),
              ),
            ),
            if (paper != null) ...[
              ClipPath(
                clipper: _PathClip((_) => Path()..addPolygon(sleeve, true)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color.lerp(paper, const Color(0xFFFFFFFF), 0.12)!,
                        paper,
                        Color.lerp(paper, const Color(0xFF000000), 0.45)!,
                      ],
                      stops: const [0.15, 0.5, 0.85],
                    ),
                  ),
                ),
              ),
              // The wrap's shade on the paper beside it.
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ClipPath(
                  clipper: _PathClip((s) => cone(s).shift(Offset(lip, lip))),
                  child: const ColoredBox(color: Color(0x80000000)),
                ),
              ),
            ],
            body,
            wall,
            // The far half of the rim goes behind the heap, the near half
            // over it.
            IgnorePointer(
              child: CustomPaint(
                painter: _RimPainter(rim, lip, half: _RimHalf.back),
              ),
            ),
            filling,
            IgnorePointer(
              child: CustomPaint(
                painter: _RimPainter(rim, lip, half: _RimHalf.front),
              ),
            ),
          ],
        );

        final frame = opening.frame;
        if (frame == null || zoom <= 0) return wrap;
        // Grow into the frame: fit it to ~94% of the box, centred.
        final f = px(frame);
        final fit = min(size.width / f.width, size.height / f.height) * 0.94;
        final k = 1 + (fit - 1) * zoom;
        final centre = Offset.lerp(f.center, size.center(Offset.zero), zoom)!;
        return Transform(
          transform: Matrix4.identity()
            ..translateByDouble(
              centre.dx - f.center.dx * k,
              centre.dy - f.center.dy * k,
              0,
              1,
            )
            ..scaleByDouble(k, k, 1, 1),
          child: wrap,
        );
      },
    );
  }
}

/// The rim: the crepe's thin cut edge, a little lighter than the walls
/// (their texture shows through), toasted darker on its outer side. [half]
/// draws only the far or the near half, so a heaped filling can sit
/// between them.
class _RimPainter extends CustomPainter {
  const _RimPainter(this.rim, this.lip, {this.half});

  final Rect rim;
  final double lip;
  final _RimHalf? half;

  @override
  void paint(Canvas canvas, Size size) {
    void ring(Rect r, Paint p) => switch (half) {
      null => canvas.drawOval(r, p),
      _RimHalf.back => canvas.drawArc(r, pi, pi, false, p),
      _RimHalf.front => canvas.drawArc(r, 0, pi, false, p),
    };
    ring(
      rim.inflate(lip / 2),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = lip
        ..color = const Color(0x40FFF1D6),
    );
    ring(
      rim.inflate(lip),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x598A5A2B),
    );
    // Where the inner wall goes down.
    ring(
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = const Color(0x403A2410),
    );
  }

  @override
  bool shouldRepaint(_RimPainter oldDelegate) =>
      oldDelegate.rim != rim ||
      oldDelegate.lip != lip ||
      oldDelegate.half != half;
}

enum _RimHalf { back, front }

/// Stretches a radial gradient across its bounds, so its circle becomes
/// the ellipse the bounds hold (a wide mound, not a round spot).
class _StretchToBounds extends GradientTransform {
  const _StretchToBounds();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final c = bounds.center;
    return Matrix4.identity()
      ..translateByDouble(c.dx, c.dy, 0, 1)
      ..scaleByDouble(bounds.width / bounds.height, 1, 1, 1)
      ..translateByDouble(-c.dx, -c.dy, 0, 1);
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
    opening: WrapOpening.from(input.params['opening']),
    contents: bakedContents(input),
  );
}

/// The product's pieces alone, baked like the product, when given.
Widget? bakedContents(AnimStepInput input) => switch (input.contents) {
  final c? => Cooked(amount: 1, child: c),
  null => null,
};

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
