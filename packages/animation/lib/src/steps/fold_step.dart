import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Fold (P2-06): folds the product along one of its fold `lines` (param, in
/// fractions of the product box), the line given by `stage` (1-based); the
/// earlier lines are already folded. The part on the line's folding side
/// turns about the line in 3D (perspective) and lands mirrored over the
/// rest; past 90° it shows the product's back (role `back`, FR-AN-03). The
/// cooking surface (role `surface`) stays underneath.
class FoldStep implements AnimStep {
  const FoldStep();

  static const _scrimColor = Color(0xFF0B0705);

  /// Where Swap starts (its first frame), which the last fold ends on.
  static const _swapFromScale = 0.9;
  static const _swapDarkness = 0.35;

  /// The last fold, in its own time (not eased): the filling heaps up into
  /// the wrap's opening from [_heapFrom] and is the finished heap at
  /// [_heapTo], while the folding side lands; the finished wrap then takes
  /// over ([_settleFrom]..[_settleTo]) and grows into its frame, the flat
  /// crepe and the griddle fading away under it.
  static const _heapFrom = 0.4;
  static const _heapTo = 0.68;
  static const _settleFrom = 0.66;
  static const _settleTo = 0.74;

  /// How tight the pieces of a folded side gather beside the crease
  /// (fraction of the width they had on that side).
  static const _gather = 0.5;

  /// The product's pieces ([pieces], the product's box) as the folds carry
  /// them: the middle stays in place; the pieces of a folding side ride on
  /// it (drawn with the product) until it stands on edge, then come out of
  /// the crease and spread, packed tight, into the middle beside it; over
  /// the last fold all of it rises and flattens into the finished wrap's
  /// heap ([WrapOpening.filling]), the heap's back layer showing as it goes.
  static Widget? _filling(
    Widget pieces,
    List<FoldLine> lines,
    int stage,
    double t,
    double time,
    WrapOpening? opening,
    Size size,
  ) {
    if (size.isEmpty) return null;
    final region = opening?.contents ?? const Rect.fromLTWH(0, 0, 1, 1);
    final heaped =
        stage == lines.length &&
        opening != null &&
        !region.isEmpty &&
        !opening.ellipse.isEmpty;
    final h = heaped
        ? interval(time, _heapFrom, _heapTo, Curves.easeInOut)
        : 0.0;
    final corners = [
      region.topLeft,
      region.topRight,
      region.bottomLeft,
      region.bottomRight,
    ].map((c) => Offset(c.dx * size.width, c.dy * size.height));

    final layers = <Widget>[ClipPath(clipper: _RestClip(lines), child: pieces)];
    for (var i = 0; i < lines.length && i < stage; i++) {
      final line = lines[i];
      final current = i == stage - 1;
      // Out of the crease once the side stands on edge; with the heap,
      // spread before it is done.
      final s = !current
          ? 1.0
          : heaped
          ? interval(time, 0.5, _heapTo)
          : interval(t, 0.5, 1);
      if (s <= 0) continue;
      final pa = Offset(line.a.dx * size.width, line.a.dy * size.height);
      final d = Offset(line.b.dx * size.width, line.b.dy * size.height) - pa;
      if (d.distance < 1e-9) continue;
      final n = Offset(d.dy, -d.dx) / d.distance; // towards the folding side
      // How far the filling reaches onto this side.
      final reach = corners
          .map((c) => (c - pa).dx * n.dx + (c - pa).dy * n.dy)
          .fold(0.0, max);
      // A piece at distance x on the folding side lands at
      // gather * (x - reach) beside the crease (in order, packed); with the
      // heap it goes back to x, where the heap's fit expects it.
      final alpha = s * (_gather + h * (1 - _gather));
      final beta = -s * (1 - h) * _gather * reach;
      layers.add(
        Transform(
          transform: _alongNormal(pa, n, alpha, beta),
          child: ClipPath(
            clipper: _MovingClip(line, lines.take(i).toList()),
            child: pieces,
          ),
        ),
      );
    }
    final spread = Stack(fit: StackFit.expand, children: layers);
    if (h <= 0) return spread;
    final o = opening!;
    final heap = o.filling(size);
    final lifted = Matrix4.identity();
    final m = heap.storage, l = lifted.storage;
    for (var k = 0; k < 16; k++) {
      l[k] = l[k] + (m[k] - l[k]) * h;
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        // The heap's second layer, behind and higher in its shade.
        Opacity(
          opacity: interval(h, 0.4, 1),
          child: Transform(
            transform: o.filling(
              size,
              grow: 0.92,
              lift: o.ellipse.height * size.height * 0.14,
              flip: true,
            ),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0x47000000),
                BlendMode.srcATop,
              ),
              child: pieces,
            ),
          ),
        ),
        Transform(transform: lifted, child: spread),
      ],
    );
  }

  /// Moves every point's distance from the line through [pa] along the unit
  /// normal [n] from x to `alpha * x + beta`, keeping it along the line.
  static Matrix4 _alongNormal(Offset pa, Offset n, double alpha, double beta) {
    final g = alpha - 1;
    final shift = beta - g * (n.dx * pa.dx + n.dy * pa.dy);
    return Matrix4(
      1 + g * n.dx * n.dx,
      g * n.dx * n.dy,
      0,
      0,
      g * n.dx * n.dy,
      1 + g * n.dy * n.dy,
      0,
      0,
      0,
      0,
      1,
      0,
      n.dx * shift,
      n.dy * shift,
      0,
      1,
    );
  }

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final p = input.params;
    final lines = FoldLine.listFrom(p['lines']);
    final stage = ((p['stage'] as num?)?.toInt() ?? 1)
        .clamp(1, max(1, lines.length))
        .toInt();
    final scrim = ((p['scrimMaxPct'] as num?)?.toDouble() ?? 30) / 100;
    final perspective = (p['perspective'] as num?)?.toDouble() ?? 0.0015;
    final rect = input.productRect;
    final back = backImage(input);
    // Folded on the griddle: it goes into its paper only as it is lifted
    // off to be served (the last moments of the last fold).
    final served = WrapOpening.from(p['opening']);
    final opening = served?.unwrapped;
    final baked = Cooked(amount: 1, child: input.product);
    if (lines.isEmpty) {
      return Stack(
        children: [Positioned.fromRect(rect: rect, child: baked)],
      );
    }
    final line = lines[stage - 1];
    final done = lines.take(stage - 1).toList();
    final t = input.reduceMotion
        ? 1.0
        : Curves.easeInOutCubic.transform(frame.t);
    final angle = pi * t;
    final lift = sin(angle);
    // How far the whole wrap has come (0 flat .. 1 every fold done): its
    // volume (rounding, shadow) builds up fold by fold.
    final progress = ((stage - 1) + t) / lines.length;
    // The moving part shows its front until edge-on, then the back.
    final face = angle > pi / 2 && back != null ? back : baked;
    // The finished wrap fades in over the last fold, once the filling has
    // heaped up as it shows it; not built while unseen.
    final time = input.reduceMotion ? 1.0 : frame.t;
    final finishing = stage == lines.length && opening != null;
    final settle = finishing ? interval(time, _settleFrom, _settleTo) : 0.0;
    // It then grows into its frame, the flat crepe fading away under it.
    final zoom = finishing
        ? interval(time, _settleTo, 1, Curves.easeInOut)
        : 0.0;
    // From when it starts to settle, it is lifted off the griddle.
    final lifted = finishing
        ? interval(time, _settleFrom, 1, Curves.easeInOut)
        : 0.0;
    final pieces = bakedContents(input);
    // Lifted off, it ends as Swap begins: its paper on, a little smaller
    // (Swap pops it from there) and the background as dark.
    final paper = served?.sleeve;
    final finished = paper == null || lifted >= 1
        ? served
        : lifted <= 0
        ? opening
        : WrapOpening(
            ellipse: served!.ellipse,
            contents: served.contents,
            frame: served.frame,
            sleeve: paper.withValues(alpha: paper.a * lifted),
          );
    final swapFrom = input.reduceMotion ? 1.0 : _swapFromScale;
    final servedScale = 1 + (swapFrom - 1) * lifted;

    // Bend: lit along the crease, darker towards the free edge, so the
    // moving part reads as curved, not as a flat card.
    Alignment at(Offset f) => Alignment(f.dx * 2 - 1, f.dy * 2 - 1);
    final mid = (line.a + line.b) / 2;
    final dir = line.b - line.a;
    final u = dir / dir.distance;
    final towardFree = Offset(u.dy, -u.dx) * 0.45; // folding side
    final bent = ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (b) => LinearGradient(
        begin: at(mid),
        end: at(mid + towardFree),
        colors: [
          const Color(0x40FFF6E6),
          const Color(0x00000000),
          Colors.black.withValues(alpha: 0.2 + 0.25 * lift),
        ],
        stops: const [0, 0.35, 1],
      ).createShader(b),
      child: face,
    );

    // Rounding across the wrap, growing with the folds.
    Widget rounded(Widget child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (b) => LinearGradient(
        colors: [
          Colors.black.withValues(alpha: 0.6 * progress),
          Colors.black.withValues(alpha: 0.13 * progress),
          Colors.white.withValues(alpha: 0.2 * progress),
          Colors.black.withValues(alpha: 0.13 * progress),
          Colors.black.withValues(alpha: 0.63 * progress),
        ],
        stops: const [0.2, 0.36, 0.5, 0.64, 0.8],
      ).createShader(b),
      child: child,
    );

    // A soft dark copy of [child], for shadows.
    Widget shadowOf(Widget child, double opacity, double blur) => ImageFiltered(
      imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(
          Colors.black.withValues(alpha: opacity),
          BlendMode.srcIn,
        ),
        child: child,
      ),
    );

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: _scrimColor.withValues(
              alpha: scrim + (_swapDarkness - scrim) * lifted,
            ),
          ),
        ),
        ?surfaceUnder(input, opacity: 1 - lifted),
        Positioned.fromRect(
          rect: rect,
          child: LayoutBuilder(
            builder: (context, box) {
              final size = box.biggest;
              // Everything that is not moving in this fold.
              final resting = Folded(
                lines: lines,
                count: done.length,
                product: baked,
                back: back,
                without: line,
              );
              final movingShape = ClipPath(
                clipper: _MovingClip(line, done),
                child: face,
              );
              final flat = Stack(
                fit: StackFit.expand,
                children: [
                  // The wrap lifts off the surface as it takes shape.
                  Transform.translate(
                    offset: Offset(0, size.height * 0.025 * progress),
                    child: shadowOf(resting, 0.4 * progress, 6),
                  ),
                  rounded(resting),
                  // The lifted part casts a shadow on what is under it:
                  // its outline seen straight down, offset and soft.
                  if (lift > 0.02)
                    Transform.translate(
                      offset: Offset(size.width, size.height) * 0.02 * lift,
                      child: Transform(
                        transform: line.turn(size, angle, 0),
                        child: shadowOf(movingShape, 0.35 * lift, 5),
                      ),
                    ),
                  // The part folding now, turning about the line.
                  Transform(
                    transform: line.turn(size, angle, perspective),
                    child: ClipPath(
                      clipper: _MovingClip(line, done),
                      // Darker as it turns away from the light; srcATop
                      // shades only the product's own pixels.
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          Colors.black.withValues(alpha: 0.2 * lift),
                          BlendMode.srcATop,
                        ),
                        child: bent,
                      ),
                    ),
                  ),
                  // The filling stays in sight: what lies on a folding side
                  // goes over with it and gathers into the middle, and the
                  // last fold heaps it all up into the wrap's opening.
                  if (pieces != null)
                    ?_filling(pieces, lines, stage, t, time, opening, size),
                ],
              );
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (zoom < 1)
                    zoom > 0 ? Opacity(opacity: 1 - zoom, child: flat) : flat,
                  // The last fold closes the wrap: it settles into its
                  // finished look (outside all round, contents inside).
                  if (settle > 0)
                    Opacity(
                      opacity: settle,
                      child: Transform.scale(
                        scale: servedScale,
                        child: Folded(
                          lines: lines,
                          count: lines.length,
                          product: baked,
                          back: back,
                          opening: finished,
                          // It grows into its frame as it settles.
                          zoom: zoom,
                          contents: pieces,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The part of the product on [line]'s folding side that earlier folds left.
class _MovingClip extends CustomClipper<Path> {
  const _MovingClip(this.line, this.done);

  final FoldLine line;
  final List<FoldLine> done;

  @override
  Path getClip(Size size) {
    var p = line.foldingSide(size);
    for (final d in done) {
      p = Path.combine(PathOperation.difference, p, d.foldingSide(size));
    }
    return Path.combine(
      PathOperation.intersect,
      p,
      Path()..addRect(Offset.zero & size),
    );
  }

  @override
  bool shouldReclip(_MovingClip oldClipper) =>
      oldClipper.line != line || !listEquals(oldClipper.done, done);
}

/// The part of the product no fold line's folding side covers (the middle).
class _RestClip extends CustomClipper<Path> {
  const _RestClip(this.lines);

  final List<FoldLine> lines;

  @override
  Path getClip(Size size) {
    var keep = Path()..addRect(Offset.zero & size);
    for (final l in lines) {
      keep = Path.combine(PathOperation.difference, keep, l.foldingSide(size));
    }
    return keep;
  }

  @override
  bool shouldReclip(_RestClip oldClipper) =>
      !listEquals(oldClipper.lines, lines);
}
