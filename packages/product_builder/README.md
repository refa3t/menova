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

Registered: `scatter`, `rings`, `band`, `drizzle`, `sauce`, `even`.

A larger size carries more pieces of the same look, not bigger ones: the
canvas draws pieces (and sauce lines) smaller by `pieceShrink(density)`, as
the canvas itself grows with the size, and `scatter` and `band` shrink their
gaps alike.

## Toppings together: JointPlacement

A strategy that also implements `JointPlacement` (e.g. `even`) lays out
several ingredients at once, so their pieces share the surface instead of
landing on each other. The canvas keeps, per joint strategy, the units in
the order they were first shown: those on the first frame are one batch
(laid out the same whatever their order, so the menu card and the product
page match), every later unit is laid out around the pieces already there.
No piece moves while the product is open; a removed unit keeps its spots
and comes back to them.

`even` puts each piece where it has the most room among a few random spots
(best-candidate sampling), away from the others and from the edge of the
area, larger pieces first. The area is the disc of `radius` (how far the
pieces' edges reach; with `inset` 0 their centres) or the strip `bandWidth`
high around `offsetX`/`offsetY`. A piece's room is `fill:<id>` (default 0.8)
of its box `pieceSize:<id>`. With `coverage`, the batch's counts are scaled
(0.5 to 1.5) so its pieces cover that share of the area: a product with one
topping and one with seven look alike full; later units take the batch's
factor.

## The base's surface

A base may leave the toppings less room than the category's own base (e.g.
a thicker rim): `BaseSpec.surface` (in (0, 1], default 1) is how far the
toppings reach on it, as a share. The canvas (`surface`) draws the toppings'
layer that much smaller around the centre, and moves it smoothly when the
base changes; the layout itself is kept.

## Liquids: LinePlacement

A strategy that also implements `LinePlacement` (e.g. `sauce`) places no
pieces: it returns polylines in the same normalized coordinates, and the
canvas draws them as a liquid (shadow, rounded body, gloss, tapered ends)
in the ingredient's `color:<id>` (ARGB) and `lineWidth:<id>` (of the base
radius). A unit added later is poured along its length; a removed one fades
out. `sauce` pours each unit as one zigzag of `lines` evenly spaced passes,
tilted by `angle:<id>` (0-180 degrees), over the disc of `radius` or the
strip `bandWidth` high around `offsetX`/`offsetY`.
