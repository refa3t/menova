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

/// A round product folded [folds] times, seen from above (P2-06): 1 is a
/// half moon (top folded down over the bottom), 2 a quarter (left folded
/// over the right). The outside of a folded crepe is its back, so the
/// visible face is [back] when given, else the product itself.
class Folded extends StatelessWidget {
  const Folded({
    super.key,
    required this.folds,
    required this.product,
    this.back,
  });

  final int folds;
  final Widget product;
  final Widget? back;

  @override
  Widget build(BuildContext context) {
    if (folds <= 0) return product;
    return ClipPath(clipper: FoldClip(folds), child: back ?? product);
  }
}

/// The disc after [folds] folds: bottom half, then bottom-right quarter.
class FoldClip extends CustomClipper<Path> {
  const FoldClip(this.folds);

  final int folds;

  @override
  Path getClip(Size size) {
    final disc = Path()..addOval(Offset.zero & size);
    final keep = folds == 1
        ? Rect.fromLTWH(0, size.height / 2, size.width, size.height / 2)
        : Rect.fromLTWH(
            size.width / 2,
            size.height / 2,
            size.width / 2,
            size.height / 2,
          );
    return Path.combine(PathOperation.intersect, disc, Path()..addRect(keep));
  }

  @override
  bool shouldReclip(FoldClip oldClipper) => oldClipper.folds != folds;
}

/// The back image a step was given (role `back`), if any.
Widget? backImage(AnimStepInput input) {
  final url = input.images['back']?.firstOrNull;
  if (url == null) return null;
  return Image.network(
    url,
    fit: BoxFit.contain,
    gaplessPlayback: true,
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// The product as the sequence has shaped it so far: baked and flat, or
/// folded `folds` times (step param) showing its back.
Widget shapedProduct(AnimStepInput input) {
  final folds = (input.params['folds'] as num?)?.toInt() ?? 0;
  if (folds <= 0) return Cooked(amount: 1, child: input.product);
  return Folded(folds: folds, product: input.product, back: backImage(input));
}

/// The cooking surface (role `surface`) under the product, slightly larger.
Widget? surfaceUnder(AnimStepInput input, {double opacity = 1}) {
  final url = input.images['surface']?.firstOrNull;
  if (url == null || opacity <= 0) return null;
  return Positioned.fromRect(
    rect: Rect.fromCenter(
      center: input.productRect.center,
      width: input.productRect.width * 1.16,
      height: input.productRect.height * 1.16,
    ),
    child: Image.network(
      url,
      fit: BoxFit.contain,
      opacity: AlwaysStoppedAnimation(opacity.clamp(0.0, 1.0)),
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    ),
  );
}
