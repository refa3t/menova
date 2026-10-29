import 'dart:math';

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
    // The moving part shows its front until edge-on, then the back.
    final face = angle > pi / 2 && back != null ? back : baked;

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
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Everything that is not moving in this fold.
                  Folded(
                    lines: lines,
                    count: done.length,
                    product: baked,
                    back: back,
                    without: line,
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
                          Colors.black.withValues(alpha: 0.25 * sin(angle)),
                          BlendMode.srcATop,
                        ),
                        child: face,
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
