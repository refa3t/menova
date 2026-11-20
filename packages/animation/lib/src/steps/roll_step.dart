import 'dart:math';

import 'package:flutter/material.dart';

import '../anim_step.dart';

/// Roll: the product, as its earlier folds left it (params `lines`, `folds`;
/// kept flat), rolls up from the bottom edge of the roll `area` into a log
/// (param `roll`, see [RollShape]). First the bottom strip lifts and turns
/// over the filling about a line across it, in 3D with `perspective` (past
/// 90° it shows the outside, role `back`); then it rolls on as a log that
/// grows as it takes up the sheet, its outside turning, until the whole sheet
/// is rolled; at the end the log settles into its `log` rect. The cooking
/// surface (role `surface`) stays underneath. Display only: a cancelled or
/// skipped roll leaves nothing behind (ARC-05).
class RollStep implements AnimStep {
  const RollStep();

  static const _scrimColor = Color(0xFF0B0705);

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
    // Rolled on the griddle: it goes into its paper only when served.
    final shape = RollShape.from(p['roll'])?.unwrapped;
    final t = input.reduceMotion ? 1.0 : frame.t;

    Widget sheetOf(Widget face) => Folded(
      lines: lines,
      count: folds,
      product: face,
      back: back,
      flat: true,
    );
    final sheet = sheetOf(baked);

    Widget content = sheet;
    if (shape != null) {
      content = LayoutBuilder(
        builder: (context, box) => _rolling(
          box.biggest,
          t,
          shape,
          sheet,
          back,
          baked,
          sheetOf,
          perspective,
        ),
      );
    }
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(color: _scrimColor.withValues(alpha: scrim)),
        ),
        ?surfaceUnder(input),
        Positioned.fromRect(rect: input.productRect, child: content),
      ],
    );
  }

  Widget _rolling(
    Size size,
    double t,
    RollShape shape,
    Widget sheet,
    Widget? back,
    Widget baked,
    Widget Function(Widget face) sheetOf,
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

    // Phases: the near edge lifts and turns over (curl), the log rolls up
    // the sheet (roll), then settles where it rests (settle).
    final curl = interval(t, 0, 0.2, Curves.easeIn);
    final roll = interval(t, 0.15, 0.85, Curves.easeInOut);
    final settle = interval(t, 0.85, 1, Curves.easeOut);
    final logIn = interval(t, 0.14, 0.22);

    final strip = min(dEnd * 1.2, a.height * 0.3);
    final hinge = a.bottom - strip;
    final y = hinge + (a.top + dEnd / 2 - hinge) * roll;
    // The log grows as it takes up the sheet (its area, so with the root).
    final d = dEnd * (0.45 + 0.55 * sqrt(roll));
    var log = Rect.fromLTRB(a.left, y - d / 2, a.right, y + d / 2);
    if (settle > 0) log = Rect.lerp(log, px(shape.settled), settle)!;
    // What is still flat: everything above the log's far side.
    final cut = y - d / 2 * roll;

    final children = <Widget>[
      ClipRect(clipper: _Above(roll > 0 ? cut : hinge), child: sheet),
    ];
    if (logIn < 1) {
      // The bottom strip turning over the filling about the hinge line.
      final line = FoldLine(
        Offset(1, hinge / size.height),
        Offset(0, hinge / size.height),
      );
      final angle = pi * 0.92 * curl;
      final lift = sin(angle);
      final face = angle > pi / 2 && back != null ? sheetOf(back) : sheet;
      children.add(
        Opacity(
          opacity: 1 - logIn,
          child: Transform(
            transform: line.turn(size, angle, perspective),
            child: ClipRect(
              clipper: _Below(hinge),
              child: ColorFiltered(
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.25 * lift),
                  BlendMode.srcATop,
                ),
                child: face,
              ),
            ),
          ),
        ),
      );
    }
    if (logIn > 0) {
      children.add(
        Opacity(
          opacity: logIn,
          child: RolledLog(
            rect: Rect.fromLTRB(
              log.left / size.width,
              log.top / size.height,
              log.right / size.width,
              log.bottom / size.height,
            ),
            product: baked,
            back: back,
            contents: shape.contents,
            turn: roll,
            // The filling shows at the open end once rolled over it.
            open: interval(roll, 0.3, 0.6),
          ),
        ),
      );
    }
    return Stack(fit: StackFit.expand, children: children);
  }
}

/// The part of the box above [y].
class _Above extends CustomClipper<Rect> {
  const _Above(this.y);

  final double y;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, 0, size.width, y.clamp(0.0, size.height));

  @override
  bool shouldReclip(_Above oldClipper) => oldClipper.y != y;
}

/// The part of the box below [y].
class _Below extends CustomClipper<Rect> {
  const _Below(this.y);

  final double y;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(0, y.clamp(0.0, size.height), size.width, size.height);

  @override
  bool shouldReclip(_Below oldClipper) => oldClipper.y != y;
}
