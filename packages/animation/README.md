# animation

Animation engine: display only. Depends on `core` only. It never reads prices or
changes the selection or cart, and a failed or cancelled animation never affects
the item (ARC-05).

## Extension point: AnimStep

1. Implement `AnimStep.build(context, t, input)` for progress `t` in [0, 1].
2. Register it once in `animSteps`, and its key in `animationStepKeys`.
3. Reference the key from a category definition's `animation` list.

Phase 1 keys: `Oven`, `Swap`, `FlyToCart` (implemented in P1-G02..G04).
