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

Registered: `scatter`, `rings`, `band`, `drizzle`, `sauce`.

## Liquids: LinePlacement

A strategy that also implements `LinePlacement` (e.g. `sauce`) places no
pieces: it returns polylines in the same normalized coordinates, and the
canvas draws them as a liquid (shadow, rounded body, gloss, tapered ends)
in the ingredient's `color:<id>` (ARGB) and `lineWidth:<id>` (of the base
radius). A unit added later is poured along its length; a removed one fades
out. `sauce` pours each unit as one zigzag of `lines` evenly spaced passes,
tilted by `angle:<id>` (0-180 degrees), over the disc of `radius` or the
strip `bandWidth` high around `offsetX`/`offsetY`.
