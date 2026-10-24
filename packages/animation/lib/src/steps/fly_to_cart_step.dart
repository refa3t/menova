import 'dart:ui';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// FlyToCart (ANIMATIONS.md 7.3): the snapshot shrinks to 18% and flies on a
/// quadratic arc into the cart icon. Reduced motion: straight line, no spin.
class FlyToCartStep implements AnimStep {
  const FlyToCartStep();

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final target = input.cartTarget;
    final rect = input.productRect;
    if (target == null) return const SizedBox.shrink();
    final p = input.params;
    final shrinkTo = (p['shrinkTo'] as num?)?.toDouble() ?? 0.18;
    final arc = ((p['arcControlPct'] as num?)?.toDouble() ?? 20) / 100;
    final rotate =
        ((p['rotateDeg'] as num?)?.toDouble() ?? -12) * 3.14159265 / 180;

    final reduce = input.reduceMotion;
    final t = reduce ? frame.t : Curves.easeInOutCubic.transform(frame.t);
    final start = rect.center;
    // Control point above the midpoint by a share of the distance.
    final mid = Offset.lerp(start, target, 0.5)!;
    final control = reduce
        ? mid
        : mid - Offset(0, (target - start).distance * arc);
    final pos = Offset(
      (1 - t) * (1 - t) * start.dx +
          2 * (1 - t) * t * control.dx +
          t * t * target.dx,
      (1 - t) * (1 - t) * start.dy +
          2 * (1 - t) * t * control.dy +
          t * t * target.dy,
    );
    final scale = lerpDouble(1, shrinkTo, t)!;
    final angle = reduce ? 0.0 : rotate * (1 - t);
    final w = rect.width, h = rect.height;
    return Stack(
      children: [
        Positioned(
          left: pos.dx - w / 2,
          top: pos.dy - h / 2,
          width: w,
          height: h,
          child: Transform.rotate(
            angle: angle,
            child: Transform.scale(
              scale: scale,
              child: Cooked(amount: 1, child: input.product),
            ),
          ),
        ),
      ],
    );
  }
}
