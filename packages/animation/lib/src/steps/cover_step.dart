import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Cover: a clear film (step param `cover`, see [CoverSpec]) is pulled
/// across the baked product from one side, then holds while the product
/// settles. The product stays as the sequence shaped it (e.g. `melt`), at
/// `scale` (0.9, where the oven left it and Swap takes over), over the
/// oven's dimmed background (`scrimMaxPct`, 35). Later steps keep the film
/// by carrying the same `cover` param. Without a `cover` param it only
/// holds the product.
///
/// With [AnimStepInput.lite] (a phone's GPU) the baked, melted product is
/// the image painted once ([LiteBaked]) and the film is cut without a path
/// clip ([Covered.lite]).
class CoverStep implements AnimStep {
  const CoverStep();

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
    final pull = input.reduceMotion
        ? 1.0
        : interval(t, 0, 0.8, Curves.easeOutCubic);
    // A small give as the film tightens at the end.
    final give = input.reduceMotion
        ? 0.0
        : 0.015 * (1 - (2 * interval(t, 0.75, 1) - 1).abs());
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: const Color(0xFF0B0705).withValues(alpha: scrim),
          ),
        ),
        Positioned.fromRect(
          rect: input.productRect,
          child: Transform.scale(
            scale: scale * (1 - give),
            child: input.lite
                ? _liteShaped(input, pull)
                : shapedProduct(input, coverProgress: pull),
          ),
        ),
      ],
    );
  }

  /// [shapedProduct] for a phone: a melted, covered product drawn from its
  /// baked look painted once. Any other shape is [shapedProduct]'s.
  static Widget _liteShaped(AnimStepInput input, double pull) {
    final p = input.params;
    final melt = MeltSpec.from(p['melt']);
    final cover = CoverSpec.from(p['cover']);
    if (BoxSpec.from(p['box']) != null || (melt == null && cover == null)) {
      return shapedProduct(input, coverProgress: pull);
    }
    final Widget baked = LiteBaked(
      product: input.product,
      share: input.product,
      melt: melt,
      baseScale: input.baseScale,
      contents: melt == null ? null : bakedContents(input),
    );
    if (cover == null) return baked;
    return Covered(
      progress: pull,
      spec: cover,
      baseScale: input.baseScale,
      lite: true,
      child: baked,
    );
  }
}
