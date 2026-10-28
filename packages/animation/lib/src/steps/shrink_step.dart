import 'dart:ui';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Shrink (P2-07): the shaped product (flat or folded, param `folds`) lifts
/// off the surface and shrinks toward `shrinkTo` with a slight turn, ready
/// to fly to the cart; the dimmed background clears.
class ShrinkStep implements AnimStep {
  const ShrinkStep();

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final p = input.params;
    final shrinkTo = (p['shrinkTo'] as num?)?.toDouble() ?? 0.7;
    final scrim = ((p['scrimMaxPct'] as num?)?.toDouble() ?? 30) / 100;
    final t = Curves.easeInOut.transform(frame.t);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF0B0705).withValues(alpha: scrim * (1 - t)),
          ),
        ),
        ?surfaceUnder(input, opacity: 1 - t),
        Positioned.fromRect(
          rect: input.productRect,
          child: Transform.rotate(
            angle: input.reduceMotion ? 0 : -0.12 * t,
            child: Transform.scale(
              scale: lerpDouble(1, shrinkTo, t)!,
              child: shapedProduct(input),
            ),
          ),
        ),
      ],
    );
  }
}
