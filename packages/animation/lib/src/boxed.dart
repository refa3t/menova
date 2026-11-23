part of 'anim_step.dart';

/// A takeaway box for a product (step param `box`): a square of `size`
/// times the product's width (at the largest size; it follows the chosen
/// size), cardboard `color` (`#RRGGBB`), its lid printed with `text` in
/// `print` colour, hinged on its `hinge` side (`top`, `bottom`, `left` or
/// `right`) and standing open at `openDeg` degrees (past upright it leans
/// back, seen from above as a short band beyond the hinge). The product lies
/// inside at `fit` of its own size.
@immutable
class BoxSpec {
  const BoxSpec({
    this.size = 1.06,
    this.color = const Color(0xFFC8975E),
    this.print = const Color(0xFFA8322A),
    this.text = '',
    this.hinge = 'top',
    this.openDeg = 105,
    this.fit = 0.9,
  });

  final double size;
  final Color color;
  final Color print;
  final String text;
  final String hinge;
  final double openDeg;
  final double fit;

  static const _hinges = {'top', 'bottom', 'left', 'right'};

  static BoxSpec? from(Object? raw) {
    if (raw is! Map) return null;
    final hinge = raw['hinge'];
    final text = raw['text'];
    return BoxSpec(
      size: _num(raw, 'size', 1.06, 0.2, 2),
      color: _hexColor(raw['color']) ?? const Color(0xFFC8975E),
      print: _hexColor(raw['print']) ?? const Color(0xFFA8322A),
      text: text is String ? text : '',
      hinge: hinge is String && _hinges.contains(hinge) ? hinge : 'top',
      openDeg: _num(raw, 'openDeg', 105, 0, 180),
      fit: _num(raw, 'fit', 0.9, 0.1, 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is BoxSpec &&
      other.size == size &&
      other.color == color &&
      other.print == print &&
      other.text == text &&
      other.hinge == hinge &&
      other.openDeg == openDeg &&
      other.fit == fit;

  @override
  int get hashCode =>
      Object.hash(size, color, print, text, hinge, openDeg, fit);
}

/// [product] in its box, seen from above: [lid] 0 is closed (the product
/// is not drawn), 1 open at the spec's `openDeg`; the product lies inside
/// at [productScale] of its box. The box fades in by [opacity]. The faces
/// are painted once and kept (each in its own repaint boundary); a frame
/// only moves them.
class Boxed extends StatelessWidget {
  const Boxed({
    super.key,
    required this.spec,
    required this.product,
    this.lid = 0,
    this.productScale = 1,
    this.opacity = 1,
    this.baseScale = 1,
    this.lite = false,
  });

  final BoxSpec spec;
  final Widget product;
  final double lid;
  final double productScale;
  final double opacity;
  final double baseScale;

  /// For a phone's GPU: the shadow and tray, and each side of the lid, are
  /// painted once into images at full strength and faded by those images
  /// (no layers), so a frame draws a few images, the lid's in perspective,
  /// instead of replaying its painting.
  final bool lite;

  /// The lid's turn about its hinge, for [angle] radians open.
  static Matrix4 lidTurn(String hinge, double angle, double side) {
    final m = Matrix4.identity()..setEntry(3, 2, side > 0 ? 1 / (side * 5) : 0);
    return switch (hinge) {
      'bottom' => m..rotateX(angle),
      'left' => m..rotateY(angle),
      'right' => m..rotateY(-angle),
      _ => m..rotateX(-angle),
    };
  }

  static Alignment _hingeAlignment(String hinge) => switch (hinge) {
    'bottom' => Alignment.bottomCenter,
    'left' => Alignment.centerLeft,
    'right' => Alignment.centerRight,
    _ => Alignment.topCenter,
  };

  @override
  Widget build(BuildContext context) {
    final open = lid.isFinite ? lid.clamp(0.0, 1.0) : 0.0;
    final a = opacity.isFinite ? opacity.clamp(0.0, 1.0) : 1.0;
    final scale = baseScale.isFinite ? baseScale.clamp(0.0, 1.0) : 1.0;
    final ps = productScale.isFinite ? productScale.clamp(0.0, 2.0) : 1.0;
    if (a == 0) {
      // Not there yet: the product alone, as it will be put in.
      return open > 0
          ? Transform.scale(scale: ps, child: product)
          : const SizedBox.expand();
    }
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.isFinite ? box.biggest : Size.zero;
        final side = size.shortestSide * spec.size * scale;
        if (side <= 0) return const SizedBox.expand();
        final tray = Rect.fromCenter(
          center: size.center(Offset.zero),
          width: side,
          height: side,
        );
        final angle = spec.openDeg * pi / 180 * open;
        final inside = angle > pi / 2;
        if (lite) {
          return _lite(tray, side, open, angle, inside, ps, a);
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fromRect(
              rect: tray.inflate(side * 0.06),
              child: RepaintBoundary(
                child: CustomPaint(painter: _BoxShadowPainter(a)),
              ),
            ),
            Positioned.fromRect(
              rect: tray,
              child: RepaintBoundary(
                child: CustomPaint(painter: _TrayPainter(spec.color, a)),
              ),
            ),
            if (open > 0)
              Positioned.fill(
                child: Transform.scale(scale: ps, child: product),
              ),
            if (angle < pi)
              Positioned.fromRect(
                rect: tray,
                child: Transform(
                  alignment: _hingeAlignment(spec.hinge),
                  transform: lidTurn(spec.hinge, angle, side),
                  child: RepaintBoundary(
                    child: CustomPaint(
                      painter: inside
                          ? _LidInsidePainter(spec.color, a)
                          : _LidPainter(spec, a),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

extension on Boxed {
  Widget _lite(
    Rect tray,
    double side,
    double open,
    double angle,
    bool inside,
    double ps,
    double a,
  ) {
    final under = tray.inflate(side * 0.06);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fromRect(
          rect: under,
          child: Still(
            inputs: ['tray', spec.color],
            opacity: a,
            child: Stack(
              fit: StackFit.expand,
              children: [
                const CustomPaint(painter: _BoxShadowPainter(1)),
                Padding(
                  padding: EdgeInsets.all(side * 0.06),
                  child: CustomPaint(painter: _TrayPainter(spec.color, 1)),
                ),
              ],
            ),
          ),
        ),
        if (open > 0)
          Positioned.fill(
            child: Transform.scale(scale: ps, child: product),
          ),
        if (angle < pi)
          Positioned.fromRect(
            rect: tray,
            child: Transform(
              alignment: Boxed._hingeAlignment(spec.hinge),
              transform: Boxed.lidTurn(spec.hinge, angle, side),
              child: Still(
                // Keyed by side so each keeps its own image.
                key: ValueKey(inside),
                inputs: ['lid', spec, inside],
                opacity: a,
                child: CustomPaint(
                  painter: inside
                      ? _LidInsidePainter(spec.color, 1)
                      : _LidPainter(spec, 1),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

Color _shade(Color c, double f, double a) => Color.from(
  alpha: (c.a * a).clamp(0.0, 1.0),
  red: (c.r * f).clamp(0.0, 1.0),
  green: (c.g * f).clamp(0.0, 1.0),
  blue: (c.b * f).clamp(0.0, 1.0),
);

class _BoxShadowPainter extends CustomPainter {
  const _BoxShadowPainter(this.opacity);

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.06)),
      Paint()
        ..shader = RadialGradient(
          radius: 0.72,
          colors: [
            const Color(0xFF000000).withValues(alpha: 0.2 * opacity),
            const Color(0x00000000),
          ],
          stops: const [0.82, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BoxShadowPainter old) => old.opacity != opacity;
}

/// The open box: cardboard walls round a lighter bottom, the far walls lit,
/// the near ones in shade, and faint flute lines.
class _TrayPainter extends CustomPainter {
  const _TrayPainter(this.color, this.opacity);

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final outer = Offset.zero & size;
    final wall = w * 0.06;
    final inner = outer.deflate(wall);
    canvas.drawRRect(
      RRect.fromRectAndRadius(outer, Radius.circular(w * 0.02)),
      Paint()..color = _shade(color, 0.92, opacity),
    );
    // Walls: top and left lit, bottom and right in shade.
    final walls = [
      (Rect.fromLTRB(inner.left, 0, inner.right, inner.top), 1.05),
      (Rect.fromLTRB(0, inner.top, inner.left, inner.bottom), 1.0),
      (Rect.fromLTRB(inner.right, inner.top, w, inner.bottom), 0.82),
      (Rect.fromLTRB(inner.left, inner.bottom, inner.right, w), 0.78),
    ];
    for (final (r, f) in walls) {
      canvas.drawRect(r, Paint()..color = _shade(color, f, opacity));
    }
    canvas.drawRect(inner, Paint()..color = _shade(color, 1.12, opacity));
    // The bottom's shadow under the far walls.
    canvas.drawRect(
      Rect.fromLTWH(inner.left, inner.top, inner.width, wall * 0.8),
      Paint()..color = _shade(color, 0.85, opacity),
    );
    final flute = Paint()
      ..color = _shade(color, 0.97, opacity)
      ..strokeWidth = max(w * 0.003, 0.5);
    for (var x = inner.left + w * 0.04; x < inner.right; x += w * 0.04) {
      canvas.drawLine(Offset(x, inner.top), Offset(x, inner.bottom), flute);
    }
  }

  @override
  bool shouldRepaint(_TrayPainter old) =>
      old.color != color || old.opacity != opacity;
}

/// The lid's inner side (seen while it stands open): plain cardboard.
class _LidInsidePainter extends CustomPainter {
  const _LidInsidePainter(this.color, this.opacity);

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.02)),
      Paint()..color = _shade(color, 1.06, opacity),
    );
    canvas.drawRect(
      rect.deflate(size.width * 0.05),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(size.width * 0.006, 0.5)
        ..color = _shade(color, 0.9, opacity),
    );
  }

  @override
  bool shouldRepaint(_LidInsidePainter old) =>
      old.color != color || old.opacity != opacity;
}

/// The lid's printed top: cardboard with a border, a round badge and the
/// text.
class _LidPainter extends CustomPainter {
  const _LidPainter(this.spec, this.opacity);

  final BoxSpec spec;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    if (w <= 0) return;
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.02)),
      Paint()..color = _shade(spec.color, 1.0, opacity),
    );
    // The edge of the lid's front flap, lit.
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - w * 0.035, w, w * 0.035),
      Paint()..color = _shade(spec.color, 1.1, opacity),
    );
    final ink = _shade(spec.print, 1, opacity);
    canvas.drawRect(
      rect.deflate(w * 0.07),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(w * 0.008, 0.5)
        ..color = ink,
    );
    final c = rect.center;
    final badge = w * 0.2;
    final hasText = spec.text.isNotEmpty;
    final at = hasText ? c.translate(0, -w * 0.1) : c;
    canvas.drawCircle(
      at,
      badge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(w * 0.014, 0.5)
        ..color = ink,
    );
    // A slice in the badge.
    canvas.drawPath(
      Path()
        ..moveTo(at.dx, at.dy + badge * 0.62)
        ..lineTo(at.dx - badge * 0.48, at.dy - badge * 0.42)
        ..quadraticBezierTo(
          at.dx,
          at.dy - badge * 0.7,
          at.dx + badge * 0.48,
          at.dy - badge * 0.42,
        )
        ..close(),
      Paint()..color = ink,
    );
    if (!hasText) return;
    final tp = TextPainter(
      text: TextSpan(
        text: spec.text,
        style: TextStyle(
          color: ink,
          fontSize: w * 0.11,
          fontWeight: FontWeight.w700,
          letterSpacing: w * 0.004,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: w * 0.8);
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy + w * 0.14));
    tp.dispose();
  }

  @override
  bool shouldRepaint(_LidPainter old) =>
      old.spec != spec || old.opacity != opacity;
}
