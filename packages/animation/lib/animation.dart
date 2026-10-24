/// Animation engine: display only. Depends on core only.
library;

import 'package:flutter/widgets.dart';

/// Extension point (P1-B07): one reusable unit of motion (oven, swap, ...).
/// A step only draws; it never reads prices or touches the selection or
/// cart (ARC-05). The step runner (P1-G01) drives `t` from 0 to 1.
abstract interface class AnimStep {
  /// Builds the frame at progress [t] in [0, 1].
  Widget build(BuildContext context, double t, AnimStepInput input);
}

/// What a step receives: the product as currently drawn and the step's
/// parameters from the category definition.
class AnimStepInput {
  const AnimStepInput({required this.product, this.params = const {}});

  final Widget product;
  final Map<String, Object?> params;
}

/// Step keys the engine registers (CLAUDE.md 5.5, phase 1). Definitions may
/// only reference these keys. Implementations are added to [animSteps] in
/// P1-G02..G04.
const animationStepKeys = {'Oven', 'Swap', 'FlyToCart'};

/// Registered step implementations by key.
final animSteps = <String, AnimStep>{};
