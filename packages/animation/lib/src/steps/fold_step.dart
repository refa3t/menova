import 'dart:math';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Fold (P2-06): one fold with perspective (Matrix4). `stage` 1 folds the
/// top half down over the bottom (half moon); `stage` 2 folds the left half
/// of the half moon over the right (quarter). Past 90° the moving part
/// shows the product's back (role `back`, FR-AN-03). The cooking surface
/// (role `surface`) stays underneath.
class FoldStep implements AnimStep {
  const FoldStep();

  static const _scrimColor = Color(0xFF0B0705);

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final p = input.params;
    final stage = (p['stage'] as num?)?.toInt() == 2 ? 2 : 1;
    final scrim = ((p['scrimMaxPct'] as num?)?.toDouble() ?? 30) / 100;
    final perspective = (p['perspective'] as num?)?.toDouble() ?? 0.0015;
    final t = input.reduceMotion
        ? 1.0
        : Curves.easeInOutCubic.transform(frame.t);
    final angle = pi * t;
    final rect = input.productRect;
    final back = backImage(input);
    // Before this fold: flat (cooked) for stage 1, half moon for stage 2.
    final before = stage == 1
        ? Cooked(amount: 1, child: input.product)
        : Folded(folds: 1, product: input.product, back: back);
    // The moving part shows its front until edge-on, then the back. After
    // the first fold the outside is already the back on both faces.
    final movingFace = angle > pi / 2 && back != null && stage == 1
        ? back
        : before;

    // The [keep] side of the full-size product, inside a half-size box.
    Widget part(Widget child, Alignment keep) => ClipRect(
      child: OverflowBox(
        alignment: keep,
        minWidth: rect.width,
        maxWidth: rect.width,
        minHeight: rect.height,
        maxHeight: rect.height,
        child: child,
      ),
    );

    // Darken the moving part as it turns away from the light.
    Widget shaded(Widget child) => Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(
              color: Colors.black.withValues(alpha: 0.28 * sin(angle)),
            ),
          ),
        ),
      ],
    );

    final Widget staying;
    final Widget moving;
    if (stage == 1) {
      // Bottom half stays; top half turns about the horizontal diameter.
      staying = Positioned(
        left: rect.left,
        top: rect.center.dy,
        width: rect.width,
        height: rect.height / 2,
        child: part(before, Alignment.bottomCenter),
      );
      moving = Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height / 2,
        child: Transform(
          alignment: Alignment.bottomCenter,
          transform: Matrix4.identity()
            ..setEntry(3, 2, perspective)
            ..rotateX(-angle),
          child: shaded(part(movingFace, Alignment.topCenter)),
        ),
      );
    } else {
      // Right quarter stays; left quarter turns about the vertical radius.
      staying = Positioned(
        left: rect.center.dx,
        top: rect.top,
        width: rect.width / 2,
        height: rect.height,
        child: part(before, Alignment.centerRight),
      );
      moving = Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width / 2,
        height: rect.height,
        child: Transform(
          alignment: Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, perspective)
            ..rotateY(angle),
          child: shaded(part(movingFace, Alignment.centerLeft)),
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        ?surfaceUnder(input),
        staying,
        moving,
      ],
    );
  }
}
