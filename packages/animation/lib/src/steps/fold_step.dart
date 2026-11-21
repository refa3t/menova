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

  /// How tight the pieces a side pushes along bunch up ahead of its edge
  /// (fraction of the width they were spread over).
  static const _bunch = 0.75;

  /// The product's pieces ([pieces], the product's box) under the folding
  /// sides, which are drawn over them: the pieces on a side go with it
  /// (drawn with the product) and end inside, under it; as a side comes
  /// down past upright it covers a band beside its crease, and the pieces
  /// there are pushed ahead of its edge into the middle, bunched up and
  /// rising a little, so the uncovered middle gathers into a pile. Over the
  /// last fold all of it rises into the finished wrap's heap
  /// ([WrapOpening.filling]), coming out from under the sides, its back
  /// layer showing as it goes.
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
    final region = opening?.contents;
    final heaped =
        stage == lines.length &&
        opening != null &&
        !region!.isEmpty &&
        !opening.ellipse.isEmpty;
    final h = heaped
        ? interval(time, _heapFrom, _heapTo, Curves.easeInOut)
        : 0.0;
    final active = lines.take(stage).toList();
    // The pieces on a side that is folding or folded go with it.
    Widget layer = ClipPath(clipper: _RestClip(active), child: pieces);
    final radius = size.shortestSide / 2;
    for (var i = 0; i < active.length; i++) {
      final line = active[i];
      final angle = i < stage - 1 ? pi : pi * t;
      if (angle <= pi / 2) continue;
      final pa = Offset(line.a.dx * size.width, line.a.dy * size.height);
      final d = Offset(line.b.dx * size.width, line.b.dy * size.height) - pa;
      if (d.distance < 1e-9) continue;
      final n = Offset(d.dy, -d.dx) / d.distance; // towards the folding side
      final c0 = size.center(Offset.zero) - pa;
      // How far the side reaches from its crease (the product is round).
      final width = radius + c0.dx * n.dx + c0.dy * n.dy;
      if (width <= 0) continue;
      // The band the side covers now (seen from above), a little short of
      // its edge; given back as the heap takes the pieces.
      final band = width * 0.9 * -cos(angle) * (1 - h);
      if (band <= 0.5) continue;
      // A piece at depth x (0..band) under the side slides out ahead of
      // the edge, to band + bunch * x: over the pieces there, packed.
      final push = Matrix4.translationValues(
        0,
        -size.height * 0.02 * band / width,
        0,
      )..multiply(_alongNormal(pa, n, _bunch, -band));
      layer = Stack(
        fit: StackFit.expand,
        children: [
          ClipPath(clipper: _BandClip(line, band, outside: true), child: layer),
          Transform(
            transform: push,
            child: ClipPath(clipper: _BandClip(line, band), child: layer),
          ),
        ],
      );
    }
    if (h <= 0) return layer;
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
        Transform(
          transform: lifted,
          child: Stack(
            fit: StackFit.expand,
            children: [
              layer,
              // What went inside the sides comes up into the heap too.
              Opacity(
                opacity: h,
                child: ClipPath(
                  clipper: _RestClip(active, invert: true),
                  child: pieces,
                ),
              ),
            ],
          ),
        ),
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
    final active = [...done, line];
    final t = input.reduceMotion
        ? 1.0
        : Curves.easeInOutCubic.transform(frame.t);
    final angle = pi * t;
    final lift = sin(angle);
    // How far the whole wrap has come (0 flat .. 1 every fold done): its
    // volume (rounding, shadow) builds up fold by fold, up to `volume`
    // (default 1; 0 keeps a folded sheet flat, e.g. one rolled up next).
    final volume = ((p['volume'] as num?)?.toDouble() ?? 1).clamp(0.0, 1.0);
    final progress = ((stage - 1) + t) / lines.length * volume;
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
    // The pieces do not change: one image, however often a fold draws
    // them (each side's band draws them again).
    final pieces = switch (bakedContents(input)) {
      final c? => Still(
        share: input.product,
        inputs: const ['pieces'],
        child: c,
      ),
      null => null,
    };
    // Lifted off, it ends as Swap begins: its paper on, a little smaller
    // (Swap pops it from there) and the background as dark.
    // The paper fades in over the wrap as it was (two still images).
    final paper = served?.sleeve != null;
    final swapFrom = input.reduceMotion ? 1.0 : _swapFromScale;
    final servedScale = 1 + (swapFrom - 1) * lifted;

    // Bend: lit along the crease, darker towards the free edge, so the
    // moving part reads as curved, not as a flat card.
    Alignment at(Offset f) => Alignment(f.dx * 2 - 1, f.dy * 2 - 1);
    final mid = (line.a + line.b) / 2;
    final dir = line.b - line.a;
    final u = dir / dir.distance;
    final towardFree = Offset(u.dy, -u.dx) * 0.45; // folding side
    // With it, darker as it turns away from the light: both in one layer
    // (each tint over the darkening; srcATop shades only its own pixels).
    final shade = Colors.black.withValues(alpha: 0.2 * lift);
    final bent = ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (b) => LinearGradient(
        begin: at(mid),
        end: at(mid + towardFree),
        colors: [
          for (final c in [
            const Color(0x40FFF6E6),
            const Color(0x00000000),
            Colors.black.withValues(alpha: 0.2 + 0.25 * lift),
          ])
            Color.alphaBlend(c, shade),
        ],
        stops: const [0, 0.35, 1],
      ).createShader(b),
      child: face,
    );

    // Rounding across the wrap, growing with the folds (none on a sheet
    // kept flat: no layer for it).
    Widget rounded(Widget child) => progress <= 0
        ? child
        : ShaderMask(
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

    // A soft dark copy of [child], for shadows: blurred once (an image),
    // its strength animated.
    Widget shadowOf(
      Widget child,
      double opacity,
      double blur,
      List<Object?> inputs,
    ) => Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Still(
        bleed: blur * 3,
        share: input.product,
        inputs: ['shadow', blur, ...inputs],
        // Kept, so not laid out and captured again every frame.
        child: Kept(
          inputs: ['shadow', blur, ...inputs, input.product, back != null],
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(
                Color(0xFF000000),
                BlendMode.srcIn,
              ),
              child: child,
            ),
          ),
        ),
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
              final filling = pieces == null
                  ? null
                  : _filling(pieces, lines, stage, t, time, opening, size);
              final flat = Stack(
                fit: StackFit.expand,
                children: [
                  // The wrap lifts off the surface as it takes shape.
                  Transform.translate(
                    offset: Offset(0, size.height * 0.025 * progress),
                    child: shadowOf(resting, 0.4 * progress, 6, [
                      stage,
                      ...lines,
                    ]),
                  ),
                  if (pieces == null)
                    rounded(resting)
                  else ...[
                    // The unfolded part, the filling on it, then the sides
                    // folded over it.
                    rounded(
                      ClipPath(
                        clipper: _RestClip([...done, line]),
                        child: baked,
                      ),
                    ),
                    if (filling != null)
                      ClipPath(clipper: _RestClip(active), child: filling),
                    if (done.isNotEmpty)
                      rounded(
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            for (var i = 0; i < done.length; i++)
                              Transform(
                                transform: done[i].reflection(size),
                                child: ClipPath(
                                  clipper: _MovingClip(
                                    done[i],
                                    done.take(i).toList(),
                                  ),
                                  child: back ?? baked,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                  // The lifted part casts a shadow on what is under it:
                  // its outline seen straight down, offset and soft.
                  if (lift > 0.02)
                    Transform.translate(
                      offset: Offset(size.width, size.height) * 0.02 * lift,
                      child: Transform(
                        transform: line.turn(size, angle, 0),
                        child: shadowOf(movingShape, 0.35 * lift, 5, [
                          stage,
                          ...lines,
                          identical(face, back),
                        ]),
                      ),
                    ),
                  // The part folding now, turning about the line.
                  Transform(
                    transform: line.turn(size, angle, perspective),
                    child: ClipPath(
                      clipper: _MovingClip(line, done),
                      child: bent,
                    ),
                  ),
                  // As the heap rises, the pile comes up out of the open
                  // end, over the sides there.
                  if (filling != null &&
                      opening != null &&
                      stage == lines.length)
                    ClipPath(
                      clipper: _RestClip(
                        active,
                        above: opening.ellipse.center.dy * size.height,
                      ),
                      child: filling,
                    ),
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
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            for (final (o, shown) in [
                              (opening, !paper || lifted < 1 ? 1.0 : 0.0),
                              (served, paper ? lifted : 0.0),
                            ])
                              if (shown > 0)
                                Opacity(
                                  key: ValueKey(identical(o, served)),
                                  opacity: shown,
                                  child: Folded(
                                    lines: lines,
                                    count: lines.length,
                                    product: baked,
                                    back: back,
                                    opening: o,
                                    // It grows into its frame as it settles.
                                    zoom: zoom,
                                    contents: pieces,
                                  ),
                                ),
                          ],
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

/// The product's [pieces] as the first [count] of the fold [lines] leave
/// them once folded flat (each side landed, without a finished wrap's
/// heap): what is under a side pushed ahead of its edge into the middle,
/// within the part no side took away. The frame a fold ends on, for a step
/// that goes on from the folded sheet (a roll).
class FoldedFilling extends StatelessWidget {
  const FoldedFilling({
    super.key,
    required this.pieces,
    required this.lines,
    required this.count,
  });

  final Widget pieces;
  final List<FoldLine> lines;
  final int count;

  @override
  Widget build(BuildContext context) {
    final n = count.clamp(0, lines.length);
    if (n == 0) return pieces;
    final active = lines.take(n).toList();
    return LayoutBuilder(
      builder: (context, box) {
        final layer = FoldStep._filling(
          pieces,
          lines,
          n,
          1,
          1,
          null,
          box.biggest,
        );
        if (layer == null) return const SizedBox.shrink();
        return ClipPath(clipper: _RestClip(active), child: layer);
      },
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
  const _RestClip(this.lines, {this.invert = false, this.above});

  final List<FoldLine> lines;

  /// Only above this height (box pixels), when given.
  final double? above;

  /// The folding sides instead (within the box).
  final bool invert;

  @override
  Path getClip(Size size) {
    var keep = Path()..addRect(Offset.zero & size);
    for (final l in lines) {
      keep = Path.combine(PathOperation.difference, keep, l.foldingSide(size));
    }
    if (above case final y?) {
      keep = Path.combine(
        PathOperation.intersect,
        keep,
        Path()..addRect(Rect.fromLTRB(0, 0, size.width, y)),
      );
    }
    if (!invert) return keep;
    return Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      keep,
    );
  }

  @override
  bool shouldReclip(_RestClip oldClipper) =>
      oldClipper.invert != invert ||
      oldClipper.above != above ||
      !listEquals(oldClipper.lines, lines);
}

/// The band [depth] pixels wide on the near (not folding) side of [line],
/// beside it; or, [outside], everything but that band.
class _BandClip extends CustomClipper<Path> {
  const _BandClip(this.line, this.depth, {this.outside = false});

  final FoldLine line;
  final double depth;
  final bool outside;

  @override
  Path getClip(Size size) {
    final pa = Offset(line.a.dx * size.width, line.a.dy * size.height);
    final d = Offset(line.b.dx * size.width, line.b.dy * size.height) - pa;
    final box = Path()..addRect(Offset.zero & size);
    if (d.distance < 1e-9) return outside ? box : Path();
    final u = d / d.distance;
    final n = Offset(u.dy, -u.dx); // towards the folding side
    final far = size.longestSide * 4;
    final band = Path()
      ..addPolygon([
        pa - u * far,
        pa + u * far,
        pa + u * far - n * depth,
        pa - u * far - n * depth,
      ], true);
    return Path.combine(
      outside ? PathOperation.difference : PathOperation.intersect,
      box,
      band,
    );
  }

  @override
  bool shouldReclip(_BandClip oldClipper) =>
      oldClipper.line != line ||
      oldClipper.depth != depth ||
      oldClipper.outside != outside;
}
