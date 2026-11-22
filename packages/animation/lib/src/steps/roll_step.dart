import 'dart:math';

import 'package:flutter/material.dart';

import '../anim_step.dart';
import 'fold_step.dart';

/// Roll: the product, as its earlier folds left it (params `lines`, `folds`;
/// kept flat, its pieces where the folds pushed them when given), rolls up
/// from the bottom edge of the roll `area` into a log (param `roll`, see
/// [RollShape]). First the bottom strip lifts and turns over about a line
/// across it, in 3D with `perspective` (past 90° it shows the outside, role
/// `back`); then it rolls on as a log that grows as it takes up the sheet,
/// its outside turning, until the whole sheet is rolled. The filling stays
/// in sight on the part still flat; just ahead of the log the sheet curls
/// up into it, gathering what lies there against it, and the log covers it
/// as it passes, the filling at its open end growing with what it has taken
/// in. At the end the log settles into its `log` rect and is lifted off,
/// in its paper (`sleeve`), ending on Swap's first frame. The cooking
/// surface (role `surface`) stays underneath until then. Display only: a
/// cancelled or skipped roll leaves nothing behind (ARC-05). Lite (a
/// phone, [AnimStepInput.lite]): the same roll with no offscreen layer or
/// blur per frame (the baked product drawn once as an image, the strip
/// not shaded as it turns, the log and the strip swapped halfway through
/// their short cross-fade, the log's own lite look, see [RolledLog]).
class RollStep implements AnimStep {
  const RollStep();

  static const _scrimColor = Color(0xFF0B0705);

  /// Where Swap starts (its first frame), which the roll ends on.
  static const _swapFromScale = 0.9;
  static const _swapDarkness = 0.35;

  @override
  Widget build(BuildContext context, AnimFrame frame, AnimStepInput input) {
    final p = input.params;
    final lines = FoldLine.listFrom(p['lines']);
    final folds = ((p['folds'] as num?)?.toInt() ?? lines.length)
        .clamp(0, lines.length)
        .toInt();
    final scrim = ((p['scrimMaxPct'] as num?)?.toDouble() ?? 30) / 100;
    final perspective = (p['perspective'] as num?)?.toDouble() ?? 0.0015;
    final back = backImage(input);
    final baked = Cooked(amount: 1, child: input.product);
    final served = RollShape.from(p['roll']);
    // Rolled on the griddle; it goes into its paper (when the shape has
    // one) as it is lifted off to be served, at the end.
    final shape = served?.unwrapped;
    final t = input.reduceMotion ? 1.0 : frame.t;
    // The filling as the side folds left it (when the pieces are given):
    // on the sheet, under the folded sides.
    final pieces = bakedContents(input);
    final filling = pieces == null
        ? null
        : FoldedFilling(pieces: pieces, lines: lines, count: folds);

    // The folded sheet does not change while it rolls: one image, which
    // the roll clips and moves (kept, so not captured again every frame).
    Widget sheetOf(Widget face, {Widget? on}) {
      final inputs = [
        'roll sheet',
        folds,
        ...lines,
        identical(face, baked),
        on != null,
      ];
      return Still(
        share: input.product,
        inputs: inputs,
        child: Kept(
          inputs: [
            ...inputs,
            input.product,
            input.contents,
            input.images['back']?.firstOrNull,
          ],
          child: Folded(
            lines: lines,
            count: folds,
            product: face,
            back: back,
            flat: true,
            contents: on,
          ),
        ),
      );
    }

    final sheet = sheetOf(baked, on: filling);

    // Lifted off at the end, it ends as Swap begins: a little smaller (Swap
    // pops it from there), in its paper, the background as dark and the
    // griddle gone (faded from earlier: it fills the screen, so slower).
    final lifted = shape == null ? 0.0 : interval(t, 0.85, 1, Curves.easeInOut);
    final away = shape == null ? 0.0 : interval(t, 0.6, 1, Curves.easeInOut);
    final swapFrom = input.reduceMotion ? 1.0 : _swapFromScale;

    Widget content = sheet;
    if (served != null && shape != null) {
      content = Transform.scale(
        scale: 1 + (swapFrom - 1) * lifted,
        child: LayoutBuilder(
          builder: (context, box) => _rolling(
            box.biggest,
            t,
            lifted,
            input,
            served,
            shape,
            sheet,
            back,
            baked,
            back == null ? null : sheetOf(back),
            perspective,
          ),
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: _scrimColor.withValues(
              alpha: scrim + (_swapDarkness - scrim) * away,
            ),
          ),
        ),
        ?surfaceUnder(input, opacity: 1 - away),
        Positioned.fromRect(rect: input.productRect, child: content),
      ],
    );
  }

  Widget _rolling(
    Size size,
    double t,
    double lifted,
    AnimStepInput input,
    RollShape served,
    RollShape shape,
    Widget sheet,
    Widget? back,
    Widget baked,
    Widget? backSheet,
    double perspective,
  ) {
    Rect px(Rect f) => Rect.fromLTRB(
      f.left * size.width,
      f.top * size.height,
      f.right * size.width,
      f.bottom * size.height,
    );
    final a = px(shape.area);
    final dEnd = shape.thickness * size.height;
    // Nothing sensible to roll: the sheet as it is.
    if (!a.isFinite || a.isEmpty || !(dEnd > 0) || !dEnd.isFinite) {
      return sheet;
    }
    // Rolled and served: the log as the steps after the roll show it (the
    // same image Swap starts with).
    if (t >= 1) return rolledProduct(input, served, baked);

    // Phases: the near edge lifts and turns over (curl), the log rolls up
    // the sheet (roll), then settles where it rests (settle).
    final curl = interval(t, 0, 0.2, Curves.easeIn);
    final roll = interval(t, 0.15, 0.85, Curves.easeInOut);
    final settle = interval(t, 0.85, 1, Curves.easeOut);
    final logIn = interval(t, 0.14, 0.22);
    final lite = input.lite;

    final strip = min(dEnd * 1.2, a.height * 0.3);
    final hinge = a.bottom - strip;
    final y = hinge + (a.top + dEnd / 2 - hinge) * roll;
    // The log grows as it takes up the sheet (its area, so with the root).
    final d = dEnd * (0.45 + 0.55 * sqrt(roll));
    var log = Rect.fromLTRB(a.left, y - d / 2, a.right, y + d / 2);
    if (settle > 0) log = Rect.lerp(log, px(shape.settled), settle)!;
    // What is still flat: everything above the log's far side.
    final edge = roll > 0 ? y - d / 2 * roll : hinge;

    // Just ahead of the log the sheet curls up into it: seen from above it
    // is foreshortened, and what lies on it is gathered against the log
    // (the sheet up to [under] past the edge drawn within [ahead] of it),
    // then rolled in under it.
    final ahead = a.height * 0.09;
    final under = ahead * 0.8 * interval(roll, 0, 0.08);
    final from = edge - ahead;
    final children = <Widget>[
      ClipRect(
        clipper: _Band(double.negativeInfinity, under > 0 ? from : edge),
        child: sheet,
      ),
      if (under > 0)
        ClipRect(
          clipper: _Band(from, edge),
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(0, from, 0, 1)
              ..scaleByDouble(1, ahead / (ahead + under), 1, 1)
              ..translateByDouble(0, -from, 0, 1),
            child: sheet,
          ),
        ),
    ];
    final flat = children.length;
    if (lite ? logIn < 0.5 : logIn < 1) {
      // The bottom strip turning over about the hinge line.
      final line = FoldLine(
        Offset(1, hinge / size.height),
        Offset(0, hinge / size.height),
      );
      final angle = pi * 0.92 * curl;
      final lift = sin(angle);
      final face = angle > pi / 2 && backSheet != null ? backSheet : sheet;
      final turning = Transform(
        transform: line.turn(size, angle, perspective),
        child: ClipRect(
          clipper: _Band(hinge, double.infinity),
          // Its shade as it turns (lite: left out; it is at most a quarter
          // black, when edge-on and barely seen) costs a layer.
          child: lite
              ? face
              : ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.25 * lift),
                    BlendMode.srcATop,
                  ),
                  child: face,
                ),
        ),
      );
      children.add(
        lite ? turning : Opacity(opacity: 1 - logIn, child: turning),
      );
    }
    if (logIn > 0) {
      // How much of the filling the log has taken in: the filling at its
      // open end grows with it, from nothing to all of it.
      final c = switch (shape.contents) {
        final r? => px(r),
        null => null,
      };
      final open = c == null || !(c.height > 0)
          ? roll
          : ((c.bottom - (y - d / 2)) / c.height).clamp(0.0, 1.0);
      final at = Rect.fromLTRB(
        log.left / size.width,
        log.top / size.height,
        log.right / size.width,
        log.bottom / size.height,
      );
      final rolled = RolledLog(
        rect: at,
        // Lite: the baked product (filters, a shader mask) drawn once as an
        // image, which the filling at the open end moves.
        product: lite
            ? Still(
                share: input.product,
                inputs: const ['roll baked'],
                child: Kept(
                  inputs: ['roll baked', input.product],
                  child: baked,
                ),
              )
            : baked,
        back: back,
        contents: shape.contents,
        // Its paper comes on as it is lifted off to be served.
        sleeve: served.sleeve,
        sleeveOpacity: lifted,
        turn: roll,
        open: open,
        lite: lite,
      );
      // Lite: under the turning strip until that goes, halfway.
      if (lite) {
        children.insert(flat, rolled);
      } else {
        children.add(Opacity(opacity: logIn, child: rolled));
      }
    }
    return Stack(fit: StackFit.expand, children: children);
  }
}

/// The part of the box between the heights [top] and [bottom].
class _Band extends CustomClipper<Rect> {
  const _Band(this.top, this.bottom);

  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    0,
    top.clamp(0.0, size.height),
    size.width,
    bottom.clamp(0.0, size.height),
  );

  @override
  bool shouldReclip(_Band oldClipper) =>
      oldClipper.top != top || oldClipper.bottom != bottom;
}
