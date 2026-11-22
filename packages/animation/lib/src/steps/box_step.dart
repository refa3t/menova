import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Box: the product's takeaway box (step param `box`, see [BoxSpec]) rises
/// open under the baked product, the product is lowered into it, and the
/// lid swings shut about its hinge in perspective with a small settle.
/// Everything sits at `scale` (0.9: where the oven left the product and
/// Swap takes over) over the oven's dimmed background (`scrimMaxPct`, 35).
/// Later steps show the closed box by carrying the same `box` param. Without
/// a `box` param it only holds the baked product.
///
/// With [AnimStepInput.lite] (a phone's GPU) the baked product is painted
/// once ([LiteBaked]) and the box's faces are images ([Boxed.lite]).
class BoxStep implements AnimStep {
  const BoxStep();

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final t = frame.t.isFinite ? frame.t.clamp(0.0, 1.0) : 1.0;
    final p = input.params;
    double param(String k, double d, double lo, double hi) {
      final v = p[k];
      return v is num && v.isFinite ? v.toDouble().clamp(lo, hi) : d;
    }

    final scale = param('scale', 0.9, 0.1, 1.5);
    final scrim = param('scrimMaxPct', 35, 0, 100) / 100;
    final spec = BoxSpec.from(p['box']);
    final Widget baked = input.lite
        ? LiteBaked(product: input.product, share: input.product)
        : Cooked(amount: 1, child: input.product);
    final still = input.reduceMotion;

    final appear = still ? 1.0 : interval(t, 0, 0.2, Curves.easeOut);
    final lower = still ? 1.0 : interval(t, 0.1, 0.45, Curves.easeInOut);
    final close = still ? 1.0 : interval(t, 0.45, 0.88, Curves.easeInOut);
    // The box settles as the lid shuts.
    final settle = still
        ? 0.0
        : 0.02 * (1 - (2 * interval(t, 0.85, 1) - 1).abs());

    final Widget content = spec == null
        ? baked
        : Boxed(
            spec: spec,
            product: baked,
            lid: 1 - close,
            // Lowered from its own size to its place in the box.
            productScale: 1 + (spec.fit - 1) * lower,
            opacity: appear,
            baseScale: input.baseScale,
            lite: input.lite,
          );
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF0B0705).withValues(alpha: scrim),
          ),
        ),
        Positioned.fromRect(
          rect: input.productRect,
          child: Transform.scale(scale: scale * (1 - settle), child: content),
        ),
      ],
    );
  }
}
