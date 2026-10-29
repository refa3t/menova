import 'dart:math';
import 'dart:ui' as ui;

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
    final opening = WrapOpening.from(p['opening']);
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
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        ?surfaceUnder(input),
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
              return Stack(
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
                  // The last fold closes the wrap: it settles into its
                  // finished look (outside all round, contents inside).
                  if (stage == lines.length && opening != null)
                    Opacity(
                      opacity: interval(t, 0.8, 1),
                      child: Folded(
                        lines: lines,
                        count: lines.length,
                        product: baked,
                        back: back,
                        opening: opening,
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
  bool shouldReclip(_MovingClip oldClipper) => true;
}
