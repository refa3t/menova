import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Swap (CLAUDE.md P1-G03): always keeps the customer's baked snapshot (never
/// a static product image) and gives it a pop (0.9 → 1.04 → 1.0) while the
/// oven darkness fades away. Lite: the shaped product drawn as one image
/// (see [shownProduct]), so a frame is that image scaled.
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
          child: Transform.scale(scale: scale, child: shownProduct(input)),
        ),
      ],
    );
  }
}

/// The product as the sequence has shaped it ([shapedProduct]), for the
/// steps that only move it (Swap, Shrink, FlyToCart). Lite (a phone): drawn
/// once into an image, shared by those steps, so the filters, masks and
/// clips in it cost once and a frame is one image with a transform.
Widget shownProduct(AnimStepInput input) {
  final shaped = shapedProduct(input);
  if (!input.lite || shaped is Still) return shaped;
  final p = input.params;
  // All the shape reads (the params as values: each step has its own map).
  final inputs = [
    'shown',
    '${p['folds']}|${p['lines']}|${p['roll']}|${p['box']}|'
        '${p['melt']}|${p['cover']}|${p['opening']}',
    input.images['back']?.firstOrNull,
    input.baseScale,
  ];
  return Still(
    bleed: input.productRect.shortestSide * 0.15,
    share: input.product,
    inputs: inputs,
    child: Kept(
      inputs: [...inputs, input.product, input.contents],
      child: shaped,
    ),
  );
}
