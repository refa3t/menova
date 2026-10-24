import 'package:flutter/widgets.dart';

/// One frame of a running step.
class AnimFrame {
  const AnimFrame({required this.t, required this.elapsed});

  /// Step progress in [0, 1].
  final double t;

  /// Wall time since the step started (for looping effects such as flames).
  final Duration elapsed;
}

/// What a step receives from the orchestrator. Display data only: the
/// engine never reads prices, the selection or the cart (ARC-05).
class AnimStepInput {
  const AnimStepInput({
    required this.product,
    required this.productRect,
    this.cartTarget,
    this.params = const {},
    this.images = const {},
    this.reduceMotion = false,
  });

  /// The customer's product as drawn when "add" was pressed (snapshot).
  final Widget product;

  /// Where the product sits on screen, in the overlay's coordinates.
  final Rect productRect;

  /// Centre of the cart icon, in the overlay's coordinates.
  final Offset? cartTarget;

  /// Step parameters from the category definition.
  final Map<String, Object?> params;

  /// Image URLs resolved from asset data by the orchestrator, by role
  /// (e.g. `hearth`, `fireBack` frames). Never hard-coded names.
  final Map<String, List<String>> images;

  final bool reduceMotion;
}

/// Extension point (P1-B07): one reusable unit of motion. A step draws the
/// whole overlay frame for its progress; it never changes app state.
abstract interface class AnimStep {
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input);
}

/// Maps a parent progress [t] to a sub-interval [begin, end] → [0, 1].
double interval(
  double t,
  double begin,
  double end, [
  Curve curve = Curves.linear,
]) {
  if (t <= begin) return 0;
  if (t >= end) return 1;
  return curve.transform((t - begin) / (end - begin));
}

/// The product looking baked by [amount] in [0, 1]: more saturated, warmer
/// and a little darker, with the crust browning from the edge inward and a
/// soft bubbling shimmer while cooking. Identity at 0.
class Cooked extends StatelessWidget {
  const Cooked({
    super.key,
    required this.amount,
    required this.child,
    this.saturation = 1.45,
    this.bubble = 0,
  });

  final double amount;
  final Widget child;

  /// Saturation reached when fully baked.
  final double saturation;

  /// Bubbling phase in [0, 1) (0 = still).
  final double bubble;

  @override
  Widget build(BuildContext context) {
    final a = amount.clamp(0.0, 1.0);
    if (a == 0) return child;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        ColorFiltered(colorFilter: cookedFilter(a, saturation), child: child),
        // Crust browning: a warm brown ring that creeps inward.
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0x00000000),
                    const Color(0x00000000),
                    const Color(0xFF6B3410).withValues(alpha: 0.45 * a),
                    const Color(0x00000000),
                  ],
                  stops: [0, 0.80 - 0.06 * a, 0.92, 1],
                ),
              ),
            ),
          ),
        ),
        // Bubbling: a faint warm shimmer drifting over the top.
        if (bubble > 0)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: Alignment(
                      0.35 * _wave(bubble),
                      0.35 * _wave(bubble + 0.25),
                    ),
                    radius: 0.55,
                    colors: [
                      const Color(0xFFFFE0A0).withValues(alpha: 0.18 * a),
                      const Color(0x00FFE0A0),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  static double _wave(double x) => (x * 2 % 2 - 1).abs() * 2 - 1;
}

/// Saturation boost, warm shift (R up, B down) and slight darkening, lerped
/// from identity by [a]. Matrix form keeps transparent edges untouched.
ColorFilter cookedFilter(double a, double saturation) {
  final s = 1 + (saturation - 1) * a;
  // Luminance weights (Rec. 709).
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final sr = (1 - s) * lr, sg = (1 - s) * lg, sb = (1 - s) * lb;
  final warmR = 1 + 0.08 * a, warmB = 1 - 0.14 * a, dark = 1 - 0.10 * a;
  return ColorFilter.matrix([
    (sr + s) * warmR * dark, sg * warmR * dark, sb * warmR * dark, 0, 0, //
    sr * dark, (sg + s) * dark, sb * dark, 0, 0, //
    sr * warmB * dark, sg * warmB * dark, (sb + s) * warmB * dark, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}
