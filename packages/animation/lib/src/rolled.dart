part of 'anim_step.dart';

/// How a product rolls up into a log (step param `roll`, fractions of the
/// product box): `area` `[x0, y0, x1, y1]` is the sheet that rolls, from its
/// bottom edge to its top; `thickness` the finished log's diameter (of the
/// box height); the optional `log` `[x0, y0, x1, y1]` where the finished log
/// settles (it grows into it), `contents` `[x0, y0, x1, y1]` the part of the
/// product (the filling) seen at its open end, and `sleeve` (`#RRGGBB`) the
/// colour of the paper it is served half wrapped in.
class RollShape {
  const RollShape({
    required this.area,
    required this.thickness,
    this.log,
    this.contents,
    this.sleeve,
  });

  final Rect area;
  final double thickness;
  final Rect? log;
  final Rect? contents;
  final Color? sleeve;

  /// The log as rolling leaves it: across the top of [area].
  Rect get rolled =>
      Rect.fromLTRB(area.left, area.top, area.right, area.top + thickness);

  /// Where the finished log rests.
  Rect get settled => log ?? rolled;

  /// The same roll before it is served (no paper yet).
  RollShape get unwrapped =>
      RollShape(area: area, thickness: thickness, log: log, contents: contents);

  static RollShape? from(Object? raw) {
    if (raw is! Map) return null;
    Rect? rect(Object? v) {
      if (v is! List || v.length != 4 || v.any((x) => x is! num)) return null;
      final n = [for (final x in v) (x as num).toDouble()];
      return Rect.fromLTRB(n[0], n[1], n[2], n[3]);
    }

    final area = rect(raw['area']);
    final thickness = raw['thickness'];
    if (area == null || thickness is! num) return null;
    final s = raw['sleeve'];
    return RollShape(
      area: area,
      thickness: thickness.toDouble(),
      log: rect(raw['log']),
      contents: rect(raw['contents']),
      sleeve: s is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)
          ? Color(0xFF000000 | int.parse(s.substring(1), radix: 16))
          : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RollShape &&
      other.area == area &&
      other.thickness == thickness &&
      other.log == log &&
      other.contents == contents &&
      other.sleeve == sleeve;

  @override
  int get hashCode => Object.hash(area, thickness, log, contents, sleeve);
}

/// The product rolled into a log, as the steps after the roll show it
/// (served, in its paper when the shape has one).
Widget rolledProduct(AnimStepInput input, RollShape roll, Widget baked) =>
    RolledLog(
      rect: roll.settled,
      product: baked,
      back: backImage(input),
      contents: roll.contents,
      sleeve: roll.sleeve,
    );

/// A rolled product seen from above (a wrap): a cylinder lying across the
/// box at [rect] (fractions of the box), its outside the product's [back]
/// (round: lit along the top, in shade below), the sheet's edge as a seam
/// that turns with it ([turn], 0 to 1 over the roll), the left end closed
/// and the right end open on the rolled layers with the filling ([contents]
/// of [product]) inside, [open] of it showing. An optional paper [sleeve]
/// wraps its left half.
class RolledLog extends StatelessWidget {
  const RolledLog({
    super.key,
    required this.rect,
    required this.product,
    this.back,
    this.contents,
    this.sleeve,
    this.turn = 1,
    this.open = 1,
  });

  final Rect rect;
  final Widget product;
  final Widget? back;
  final Rect? contents;
  final Color? sleeve;
  final double turn;
  final double open;

  /// The tortilla's colour where no image shows (and under its outside).
  static const _sheet = Color(0xFFE9D3A2);

  /// The inside of the rolled layers at the open end.
  static const _inside = Color(0xFFF0DDB2);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final r = Rect.fromLTRB(
          rect.left * size.width,
          rect.top * size.height,
          rect.right * size.width,
          rect.bottom * size.height,
        );
        if (!r.isFinite || r.width <= 0 || r.height <= 0) {
          return const SizedBox.shrink();
        }
        final h = r.height;
        // The ends, seen at a slant: narrow ovals as high as the log.
        final e = min(h * 0.36, r.width * 0.3);
        final leftEnd = Rect.fromCenter(
          center: Offset(r.left + e / 2, r.center.dy),
          width: e,
          height: h,
        );
        final rightEnd = Rect.fromCenter(
          center: Offset(r.right - e / 2, r.center.dy),
          width: e,
          height: h,
        );
        final body = Rect.fromLTRB(
          leftEnd.center.dx,
          r.top,
          rightEnd.center.dx,
          r.bottom,
        );
        final geometry = [size, rect];
        Path side(Size _) => Path.combine(
          PathOperation.union,
          Path()..addRect(body),
          Path()..addOval(leftEnd),
        );
        Path outline(Size s) => Path.combine(
          PathOperation.union,
          side(s),
          Path()..addOval(rightEnd),
        );

        // The outside turns as it rolls: its texture slides along it.
        final slack = max(0.0, r.width * 0.62 - h / 2);
        final shift = slack * (1 - 2 * turn.clamp(0.0, 1.0));
        final outside = ClipPath(
          clipper: _PathClip(side, geometry),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: r,
                child: const ColoredBox(color: _sheet),
              ),
              if (back case final b?)
                Positioned.fromRect(
                  rect: Rect.fromCenter(
                    center: r.center + Offset(0, shift),
                    width: r.width * 1.3,
                    height: r.width * 1.3,
                  ),
                  child: b,
                ),
              // Round: shade at the far and near sides, lit along the top.
              Positioned.fromRect(
                rect: r,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x80000000),
                        Color(0x14000000),
                        Color(0x30FFF3DC),
                        Color(0x00000000),
                        Color(0x40000000),
                        Color(0xA0000000),
                      ],
                      stops: [0, 0.16, 0.32, 0.5, 0.78, 1],
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: CustomPaint(
                  painter: _SeamPainter(body, turn.clamp(0.0, 1.0)),
                ),
              ),
            ],
          ),
        );

        // The open end: the rolled layers around the filling.
        final region = switch (contents) {
          final c? => Rect.fromLTRB(
            c.left * size.width,
            c.top * size.height,
            c.right * size.width,
            c.bottom * size.height,
          ),
          null => null,
        };
        final show = open.clamp(0.0, 1.0);
        Widget? filling;
        if (region != null && !region.isEmpty && show > 0) {
          final k = h * 0.8 / region.height;
          final c = rightEnd.center;
          filling = Opacity(
            opacity: show,
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(c.dx, c.dy, 0, 1)
                // Seen end-on, the filling is narrow (like the end itself).
                ..scaleByDouble(k * 0.55, k, 1, 1)
                ..translateByDouble(-region.center.dx, -region.center.dy, 0, 1),
              child: SizedBox.fromSize(size: size, child: product),
            ),
          );
        }
        final end = ClipPath(
          clipper: _PathClip((_) => Path()..addOval(rightEnd), geometry),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: rightEnd,
                child: const ColoredBox(color: _inside),
              ),
              ?filling,
              IgnorePointer(child: CustomPaint(painter: _EndPainter(rightEnd))),
            ],
          ),
        );

        final paper = sleeve;
        final cut = [
          Offset(r.left - e * 0.25, r.top - h * 0.1),
          Offset(r.left + r.width * 0.46, r.top - h * 0.1),
          Offset(r.left + r.width * 0.54, r.bottom + h * 0.1),
          Offset(r.left - e * 0.25, r.bottom + h * 0.1),
        ];

        return Stack(
          fit: StackFit.expand,
          children: [
            // Soft contact shadow under the log.
            Transform.translate(
              offset: Offset(r.width * 0.01, h * 0.14),
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
                child: ClipPath(
                  clipper: _PathClip(outline, geometry),
                  child: const ColoredBox(color: Color(0x66000000)),
                ),
              ),
            ),
            outside,
            // The closed end: the sides folded in, a crease where they turn.
            IgnorePointer(
              child: CustomPaint(painter: _ClosedEndPainter(leftEnd)),
            ),
            end,
            if (paper != null) ...[
              // The paper's shade on the log beside its slanted edge.
              ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: ClipPath(
                  clipper: _PathClip(
                    (_) => Path()
                      ..addPolygon([
                        for (final p in cut) p + Offset(h * 0.06, 0),
                      ], true),
                    geometry,
                  ),
                  child: const ColoredBox(color: Color(0x59000000)),
                ),
              ),
              ClipPath(
                clipper: _PathClip(
                  (_) => Path()..addPolygon(cut, true),
                  geometry,
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(paper, const Color(0xFF000000), 0.25)!,
                        Color.lerp(paper, const Color(0xFFFFFFFF), 0.3)!,
                        paper,
                        Color.lerp(paper, const Color(0xFF000000), 0.4)!,
                      ],
                      stops: [
                        for (final y in [
                          r.top - h * 0.1,
                          r.top + h * 0.3,
                          r.top + h * 0.6,
                          r.bottom + h * 0.1,
                        ])
                          (y / size.height).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The sheet's outer edge along the log: it goes round as the log turns, so
/// it shows only while on the top side.
class _SeamPainter extends CustomPainter {
  const _SeamPainter(this.body, this.turn);

  final Rect body;
  final double turn;

  @override
  void paint(Canvas canvas, Size size) {
    // About one and a half turns over the roll.
    final angle = turn * 3 * pi + 0.6;
    final facing = sin(angle);
    if (facing <= 0) return;
    final y = body.center.dy - body.height / 2 * cos(angle) * 0.9;
    canvas.drawLine(
      Offset(body.left, y),
      Offset(body.right, y),
      Paint()
        ..color = Color.fromRGBO(70, 40, 16, 0.35 * facing)
        ..strokeWidth = max(1.0, body.height * 0.025),
    );
  }

  @override
  bool shouldRepaint(_SeamPainter oldDelegate) =>
      oldDelegate.body != body || oldDelegate.turn != turn;
}

/// The open end: the rolled layers as rings around the filling.
class _EndPainter extends CustomPainter {
  const _EndPainter(this.end);

  final Rect end;

  @override
  void paint(Canvas canvas, Size size) {
    final layer = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.0, end.height * 0.05)
      ..color = const Color(0xFFE2C38C);
    for (final k in [0.04, 0.12]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: end.center,
          width: end.width * (1 - 2 * k),
          height: end.height * (1 - 2 * k),
        ),
        layer,
      );
    }
    canvas.drawOval(
      end.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0x998A5A2B),
    );
  }

  @override
  bool shouldRepaint(_EndPainter oldDelegate) => oldDelegate.end != end;
}

/// The closed end: shade where the folded-in side turns under.
class _ClosedEndPainter extends CustomPainter {
  const _ClosedEndPainter(this.end);

  final Rect end;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      end.deflate(end.width * 0.18),
      pi * 0.6,
      pi * 0.8,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(1.0, end.height * 0.03)
        ..color = const Color(0x553A2410)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(_ClosedEndPainter oldDelegate) => oldDelegate.end != end;
}
