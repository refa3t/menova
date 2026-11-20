part of 'anim_step.dart';

const _white = Color(0xFFFFFFFF);

Color? _hexColor(Object? s) =>
    s is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(s)
    ? Color(0xFF000000 | int.parse(s.substring(1), radix: 16))
    : null;

double _num(Map raw, String key, double d, double lo, double hi) {
  final v = raw[key];
  return v is num && v.isFinite ? v.toDouble().clamp(lo, hi) : d;
}

/// How a product's top melts (step param `melt`): over a circle of `area`
/// (of half the box, at the largest size) the surface softens (`blur`,
/// logical pixels), takes a melted `color` (`#RRGGBB`) by `tint` (0..1) and
/// shines, and its pieces sink into it: they soften and fade by `sink`
/// (0..1), as if half covered.
@immutable
class MeltSpec {
  const MeltSpec({
    this.area = 0.74,
    this.color = const Color(0xFFF0B648),
    this.blur = 1.6,
    this.tint = 0.4,
    this.sink = 0.45,
  });

  final double area;
  final Color color;
  final double blur;
  final double tint;
  final double sink;

  static MeltSpec? from(Object? raw) {
    if (raw is! Map) return null;
    return MeltSpec(
      area: _num(raw, 'area', 0.74, 0, 1),
      color: _hexColor(raw['color']) ?? const Color(0xFFF0B648),
      blur: _num(raw, 'blur', 1.6, 0, 8),
      tint: _num(raw, 'tint', 0.4, 0, 1),
      sink: _num(raw, 'sink', 0.45, 0, 1),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MeltSpec &&
      other.area == area &&
      other.color == color &&
      other.blur == blur &&
      other.tint == tint &&
      other.sink == sink;

  @override
  int get hashCode => Object.hash(area, color, blur, tint, sink);
}

/// [child] (the product) melting by [amount] in [0, 1]: inside the melt
/// circle its surface blurs and turns the melted colour, so the pieces drawn
/// in it blend into the cheese; the [contents] (its pieces alone, same box)
/// lie on top, sinking: smaller, softer and fading by the spec's `sink`.
/// Identity at 0.
class Melted extends StatelessWidget {
  const Melted({
    super.key,
    required this.amount,
    required this.spec,
    required this.child,
    this.contents,
    this.baseScale = 1,
    this.gloss = 0,
  });

  final double amount;
  final MeltSpec spec;
  final Widget child;
  final Widget? contents;
  final double baseScale;

  /// Phase of a slow drifting shine, in [0, 1).
  final double gloss;

  @override
  Widget build(BuildContext context) {
    final a = amount.isFinite ? amount.clamp(0.0, 1.0) : 1.0;
    if (a == 0) return child;
    final area = (spec.area * (baseScale.isFinite ? baseScale : 1)).clamp(
      0.0,
      1.0,
    );
    final sigma = spec.blur * a;
    final pieces = contents;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest.isFinite ? box.biggest : Size.zero;
        final r = size.shortestSide / 2 * area;
        final circle = Rect.fromCircle(
          center: size.center(Offset.zero),
          radius: r,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (r > 0) ...[
              // The melted surface: the same product, softened.
              if (sigma > 0.05)
                ClipPath(
                  clipper: _CircleClip(circle),
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(
                      sigmaX: sigma,
                      sigmaY: sigma,
                    ),
                    child: child,
                  ),
                ),
              // Melted cheese running over everything inside the pan.
              CustomPaint(
                painter: _MeltPainter(
                  circle: circle,
                  color: spec.color,
                  tint: spec.tint * a,
                  gloss: gloss,
                ),
              ),
            ],
            // The pieces, sinking into it.
            if (pieces != null)
              Opacity(
                opacity: (1 - spec.sink * a).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1 - 0.04 * a,
                  child: sigma > 0.05
                      ? ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(
                            sigmaX: sigma * 0.4,
                            sigmaY: sigma * 0.4,
                          ),
                          child: pieces,
                        )
                      : pieces,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CircleClip extends CustomClipper<Path> {
  const _CircleClip(this.circle);

  final Rect circle;

  @override
  Path getClip(Size size) => Path()..addOval(circle);

  @override
  bool shouldReclip(_CircleClip oldClipper) => oldClipper.circle != circle;
}

class _MeltPainter extends CustomPainter {
  _MeltPainter({
    required this.circle,
    required this.color,
    required this.tint,
    required this.gloss,
  });

  final Rect circle;
  final Color color;
  final double tint;
  final double gloss;

  @override
  void paint(Canvas canvas, Size size) {
    if (circle.isEmpty || tint <= 0) return;
    canvas.drawOval(
      circle,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: tint),
            color.withValues(alpha: tint * 0.85),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.8, 1],
        ).createShader(circle),
    );
    // A soft shine drifting across the melted top.
    final g = gloss * 2 * pi;
    canvas.drawOval(
      circle,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-0.35 + 0.15 * sin(g), -0.4 + 0.1 * cos(g)),
          radius: 0.45,
          colors: [
            const Color(0xFFFFF6DC).withValues(alpha: 0.35 * tint / 0.4),
            const Color(0x00FFF6DC),
          ],
        ).createShader(circle),
    );
  }

  @override
  bool shouldRepaint(_MeltPainter old) =>
      old.circle != circle ||
      old.color != color ||
      old.tint != tint ||
      old.gloss != gloss;
}

/// A clear film stretched over a product (step param `cover`): a circle of
/// `area` (of half the box, at the largest size) tinted `color`
/// (`#RRGGBB`) at `opacity`, with highlights by `gloss` (0..1) and wrinkles
/// at its rim, pulled across from `from` (`left`, `right`, `top` or
/// `bottom`).
@immutable
class CoverSpec {
  const CoverSpec({
    this.area = 0.9,
    this.color = const Color(0xFFE8F2FA),
    this.opacity = 0.16,
    this.gloss = 0.7,
    this.side = 'left',
  });

  final double area;
  final Color color;
  final double opacity;
  final double gloss;
  final String side;

  static const _sides = {'left', 'right', 'top', 'bottom'};

  static CoverSpec? from(Object? raw) {
    if (raw is! Map) return null;
    final side = raw['from'];
    return CoverSpec(
      area: _num(raw, 'area', 0.9, 0, 1),
      color: _hexColor(raw['color']) ?? const Color(0xFFE8F2FA),
      opacity: _num(raw, 'opacity', 0.16, 0, 1),
      gloss: _num(raw, 'gloss', 0.7, 0, 1),
      side: side is String && _sides.contains(side) ? side : 'left',
    );
  }

  /// The unit vector the film is pulled along.
  Offset get direction => switch (side) {
    'right' => const Offset(-1, 0),
    'top' => const Offset(0, 1),
    'bottom' => const Offset(0, -1),
    _ => const Offset(1, 0),
  };

  @override
  bool operator ==(Object other) =>
      other is CoverSpec &&
      other.area == area &&
      other.color == color &&
      other.opacity == opacity &&
      other.gloss == gloss &&
      other.side == side;

  @override
  int get hashCode => Object.hash(area, color, opacity, gloss, side);
}

/// [child] with the film over it, pulled [progress] (0..1) of the way
/// across. Identity at 0.
class Covered extends StatelessWidget {
  const Covered({
    super.key,
    required this.progress,
    required this.spec,
    required this.child,
    this.baseScale = 1,
  });

  final double progress;
  final CoverSpec spec;
  final Widget child;
  final double baseScale;

  @override
  Widget build(BuildContext context) {
    final p = progress.isFinite ? progress.clamp(0.0, 1.0) : 1.0;
    if (p == 0) return child;
    final area = (spec.area * (baseScale.isFinite ? baseScale : 1)).clamp(
      0.0,
      1.0,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: _FilmPainter(spec: spec, area: area, progress: p),
          ),
        ),
      ],
    );
  }
}

class _FilmPainter extends CustomPainter {
  _FilmPainter({
    required this.spec,
    required this.area,
    required this.progress,
  });

  final CoverSpec spec;
  final double area;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2 * area;
    if (r <= 0) return;
    final c = size.center(Offset.zero);
    final circle = Rect.fromCircle(center: c, radius: r);
    final d = spec.direction;
    // The pulled part: from the starting side up to the leading edge.
    final lead = c + d * (r * (2 * progress - 1));
    final normal = Offset(-d.dy, d.dx);
    final far = r * 2;
    final pulled = Path()
      ..moveTo((c - d * far + normal * far).dx, (c - d * far + normal * far).dy)
      ..lineTo((c - d * far - normal * far).dx, (c - d * far - normal * far).dy)
      ..lineTo((lead - normal * far).dx, (lead - normal * far).dy)
      ..lineTo((lead + normal * far).dx, (lead + normal * far).dy)
      ..close();
    final film = Path.combine(
      PathOperation.intersect,
      Path()..addOval(circle.inflate(r * 0.02)),
      pulled,
    );
    canvas.save();
    canvas.clipPath(film);
    canvas.drawOval(
      circle.inflate(r * 0.02),
      Paint()..color = spec.color.withValues(alpha: spec.opacity),
    );
    // Gloss: two soft diagonal streaks and a bright spot.
    final g = spec.gloss;
    for (final (x, w, a) in [(-0.35, 0.16, 0.5), (0.1, 0.08, 0.35)]) {
      canvas.drawRect(
        circle,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0x00FFFFFF),
              _white.withValues(alpha: a * g),
              const Color(0x00FFFFFF),
            ],
            stops: [
              (0.5 + x - w).clamp(0.0, 1.0),
              (0.5 + x).clamp(0.0, 1.0),
              (0.5 + x + w).clamp(0.0, 1.0),
            ],
          ).createShader(circle),
      );
    }
    canvas.drawCircle(
      c + Offset(-r * 0.45, -r * 0.45),
      r * 0.12,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                _white.withValues(alpha: 0.7 * g),
                const Color(0x00FFFFFF),
              ],
            ).createShader(
              Rect.fromCircle(
                center: c + Offset(-r * 0.45, -r * 0.45),
                radius: r * 0.12,
              ),
            ),
    );
    // Wrinkles where the film is pulled down over the rim.
    final wrinkle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(r * 0.012, 0.5)
      ..color = _white.withValues(alpha: 0.45 * g);
    final rng = Random(5);
    for (var i = 0; i < 14; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final len = r * (0.06 + 0.08 * rng.nextDouble());
      final at = c + Offset(cos(a), sin(a)) * r * 0.97;
      final inward = Offset(cos(a), sin(a)) * -len;
      final bend = Offset(-sin(a), cos(a)) * len * 0.25;
      canvas.drawPath(
        Path()
          ..moveTo(at.dx, at.dy)
          ..quadraticBezierTo(
            (at + inward / 2 + bend).dx,
            (at + inward / 2 + bend).dy,
            (at + inward).dx,
            (at + inward).dy,
          ),
        wrinkle,
      );
    }
    // The film's edge round the rim.
    canvas.drawOval(
      circle,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = max(r * 0.025, 0.5)
        ..color = _white.withValues(alpha: 0.4 * g + 0.1),
    );
    canvas.restore();
    // The leading edge while it is being pulled.
    if (progress < 1) {
      final half = sqrt(max(r * r - pow((lead - c).distance, 2), 0)).toDouble();
      canvas.drawLine(
        lead + normal * half,
        lead - normal * half,
        Paint()
          ..strokeWidth = max(r * 0.03, 1)
          ..color = _white.withValues(alpha: 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(_FilmPainter old) =>
      old.spec != spec || old.area != area || old.progress != progress;
}
