/// Animation engine: display only. Depends on core only.
library;

import 'src/anim_step.dart';
import 'src/steps/fly_to_cart_step.dart';
import 'src/steps/fold_step.dart';
import 'src/steps/griddle_step.dart';
import 'src/steps/oven_step.dart';
import 'src/steps/shrink_step.dart';
import 'src/steps/swap_step.dart';

export 'src/anim_step.dart';
export 'src/step_runner.dart';
export 'src/steps/fly_to_cart_step.dart';
export 'src/steps/fold_step.dart';
export 'src/steps/griddle_step.dart';
export 'src/steps/oven_step.dart';
export 'src/steps/shrink_step.dart';
export 'src/steps/swap_step.dart';

/// Registered step implementations by key (CLAUDE.md 5.5, phase 1).
const animSteps = <String, AnimStep>{
  'Oven': OvenStep(),
  'Griddle': GriddleStep(),
  'Fold': FoldStep(),
  'Swap': SwapStep(),
  'Shrink': ShrinkStep(),
  'FlyToCart': FlyToCartStep(),
};

/// Step keys definitions may reference.
final animationStepKeys = animSteps.keys.toSet();
