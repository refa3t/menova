import 'dart:math';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Wood-fired oven seen from above (OVEN.md). Layer timings follow OVEN.md
/// section 3 on a 1000ms step; they scale with the actual step duration.
/// Missing images degrade to the code-drawn layers (OVEN.md 7, "minimum").
class OvenStep implements AnimStep {
  const OvenStep();

  static const _scrimColor = Color(0xFF0B0705);
  static const _warm = Color(0xFFFF7A1A);
  static const _flashColor = Color(0xFFFFE2B0);

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final t = frame.t;
    final p = input.params;
    double param(String k, double d) => (p[k] as num?)?.toDouble() ?? d;
    final scrimMax = param('scrimMaxPct', 35) / 100;
    final vignetteMax = param('vignetteMaxPct', 45) / 100;
    final shrinkTo = param('shrinkTo', 0.9);
    final saturation = param('saturation', 1.45);
    final flashPeak = param('flashPeakPct', 35) / 100;

    final rect = input.productRect;
    final scene = rect.width * 1.43; // OVEN.md 1: S ≈ 1.43 × canvas.
    final center = rect.center;

    // Layer curves (fractions of the 1000ms step).
    final scrim = interval(t, 0, 0.25) * scrimMax;
    final hearthIn = interval(t, 0, 0.3, Curves.easeOut);
    final glow =
        interval(t, 0, 0.4) * 0.5 +
        (t > 0.4 && t < 0.85
            ? sin(frame.elapsed.inMilliseconds / 1000 * 2 * pi * 2) * 0.075
            : 0) +
        (t >= 0.85 && t <= 0.93 ? 0.3 : 0);
    final fireBack = interval(t, 0.1, 0.4);
    final fireFront = interval(t, 0.25, 0.5) * 0.8;
    final rimIn = interval(t, 0, 0.25, Curves.easeOut);
    final vignette = interval(t, 0, 0.25) * vignetteMax;
    final flash = t < 0.85 || t > 0.93
        ? 0.0
        : (1 - ((t - 0.89).abs() / 0.04)).clamp(0.0, 1.0) * flashPeak;
    final embers = interval(t, 0.2, 0.35) * (1 - interval(t, 0.9, 1));
    final steam = interval(t, 0.4, 0.6) * (1 - interval(t, 0.95, 1));
    final pizzaScale =
        1 - (1 - shrinkTo) * interval(t, 0.15, 0.85, Curves.easeInOut);
    final pizzaDrop = rect.height * 0.02 * interval(t, 0.15, 0.85);
    // Cooking runs over most of the step so the change is visible.
    final cook = interval(t, 0.15, 0.9, Curves.easeInOut);
    final bubble = t > 0.35 && t < 0.95
        ? (frame.elapsed.inMilliseconds % 1600) / 1600
        : 0.0;
    final sizzle = t > 0.4 && t < 0.8
        ? sin(frame.elapsed.inMilliseconds / 1000 * 2 * pi * 24) * 0.6
        : 0.0;

    String? frameUrl(String role, int fps) {
      final frames = input.images[role];
      if (frames == null || frames.isEmpty) return null;
      final i = (frame.elapsed.inMilliseconds * fps ~/ 1000) % frames.length;
      return frames[i];
    }

    Widget layer(String? url, double opacity, {double scale = 1}) {
      if (url == null || opacity <= 0) return const SizedBox.shrink();
      return Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: scale,
          child: Image.network(
            url,
            width: scene,
            height: scene,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    String? first(String role) => input.images[role]?.firstOrNull;

    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        Positioned(
          left: center.dx - scene / 2,
          top: center.dy - scene / 2,
          width: scene,
          height: scene,
          child: Stack(
            alignment: Alignment.center,
            children: [
              layer(first('hearth'), hearthIn, scale: 1.12 - 0.12 * hearthIn),
              // Heat glow (code).
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        _warm.withValues(alpha: glow.clamp(0.0, 1.0)),
                        _warm.withValues(alpha: 0),
                      ],
                      stops: const [0.35, 0.7],
                    ),
                  ),
                ),
              ),
              layer(
                frameUrl('fireBack', 10),
                fireBack,
                scale: 0.9 + 0.1 * fireBack,
              ),
              layer(first('embers'), embers),
              // The customer's pizza: shrinks into the oven, warms, sizzles.
              Transform.translate(
                offset: Offset(sizzle, pizzaDrop + sizzle / 2),
                child: Transform.scale(
                  scale: pizzaScale,
                  child: SizedBox(
                    width: rect.width,
                    height: rect.height,
                    child: Cooked(
                      amount: cook,
                      saturation: saturation,
                      bubble: bubble,
                      child: input.product,
                    ),
                  ),
                ),
              ),
              layer(frameUrl('fireFront', 10), fireFront),
              layer(first('steam'), steam),
              layer(first('rim'), rimIn, scale: 1.15 - 0.15 * rimIn),
            ],
          ),
        ),
        // Vignette (code), centred on the scene and wide enough to reach the
        // screen corners.
        Positioned(
          left: center.dx - scene * 1.5,
          top: center.dy - scene * 1.5,
          width: scene * 3,
          height: scene * 3,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0),
                    Colors.black.withValues(alpha: vignette),
                  ],
                  stops: const [0.15, 0.4],
                ),
              ),
            ),
          ),
        ),
        if (flash > 0)
          Positioned(
            left: center.dx - scene / 2,
            top: center.dy - scene / 2,
            width: scene,
            height: scene,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      _flashColor.withValues(alpha: flash),
                      _flashColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
