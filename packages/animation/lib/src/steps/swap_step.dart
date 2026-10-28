import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Swap (CLAUDE.md P1-G03): always keeps the customer's baked snapshot (never
/// a static product image) and gives it a pop (0.9 → 1.04 → 1.0) while the
/// oven darkness fades away.
class SwapStep implements AnimStep {
  const SwapStep();

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final t = frame.t;
    final rect = input.productRect;
    final fromScale = input.reduceMotion ? 1.0 : 0.9;
    final scale = input.reduceMotion
        ? 1.0
        : t < 0.6
        ? fromScale + (1.04 - fromScale) * Curves.easeOut.transform(t / 0.6)
        : 1.04 - 0.04 * Curves.easeOutBack.transform((t - 0.6) / 0.4);
    final darkness = (1 - t).clamp(0.0, 1.0) * 0.35;
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF0B0705).withValues(alpha: darkness),
          ),
        ),
        Positioned.fromRect(
          rect: rect,
          child: Transform.scale(scale: scale, child: shapedProduct(input)),
        ),
      ],
    );
  }
}
