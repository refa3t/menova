import 'dart:math';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Griddle (P2-05): the cooking surface fades in under the product, which
/// settles onto it, cooks golden (Cooked) and steams, with a light sizzle.
/// Images by role: `surface`, `steam`. Missing images degrade to the
/// product cooking over a dimmed background.
class GriddleStep implements AnimStep {
  const GriddleStep();

  static const _scrimColor = Color(0xFF0B0705);

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final t = frame.t;
    final p = input.params;
    double param(String k, double d) => (p[k] as num?)?.toDouble() ?? d;
    final scrimMax = param('scrimMaxPct', 30) / 100;
    final saturation = param('saturation', 1.25);
    final rect = input.productRect;

    final scrim = interval(t, 0, 0.2) * scrimMax;
    final surfaceIn = interval(t, 0, 0.25, Curves.easeOut);
    final settle = 1 - 0.05 * interval(t, 0.1, 0.3, Curves.easeOut);
    final cook = interval(t, 0.2, 0.9, Curves.easeInOut);
    final steam = interval(t, 0.35, 0.55) * (1 - interval(t, 0.9, 1)) * 0.8;
    final sizzle = t > 0.3 && t < 0.85 && !input.reduceMotion
        ? sin(frame.elapsed.inMilliseconds / 1000 * 2 * pi * 20) * 0.5
        : 0.0;
    final steamUrl = input.images['steam']?.firstOrNull;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        ?surfaceUnder(input, opacity: surfaceIn),
        Positioned.fromRect(
          rect: rect.shift(Offset(sizzle, 0)),
          child: Transform.scale(
            scale: settle,
            child: Cooked(
              amount: cook,
              saturation: saturation,
              child: input.product,
            ),
          ),
        ),
        if (steamUrl != null && steam > 0)
          Positioned.fromRect(
            rect: rect.translate(0, -rect.height * 0.08 * steam),
            child: IgnorePointer(
              child: Image.network(
                steamUrl,
                fit: BoxFit.contain,
                opacity: AlwaysStoppedAnimation(steam),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
      ],
    );
  }
}
