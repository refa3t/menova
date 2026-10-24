/// Animation engine: display only. Depends on core only.
library;

/// Step keys the engine registers (CLAUDE.md 5.5, phase 1). Implementations
/// land in P1-G02..G04; definitions may only reference these keys.
const animationStepKeys = {'Oven', 'Swap', 'FlyToCart'};
