# product_builder

Product builder engine: selection, constraints and drawing. Depends on `core` only.

## Extension point: PlacementStrategy

A placement strategy decides where an ingredient's pieces go on the base.

1. Implement `PlacementStrategy.place` deterministically: the same ingredient
   and unit must always give the same pieces, on every platform. Use
   `StableRandom` and `stableSeed`, never `dart:math` `Random`.
2. Register it once in `placementStrategies` under a key.
3. Reference that key from a category definition (`placement.strategy`).
   Parameters come from `placement.params`; per-ingredient overrides use
   `<param>:<ingredientId>`.

Registered: `scatter`.
