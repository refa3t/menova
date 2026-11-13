import 'dart:math';

import 'package:flutter/material.dart';

import 'motion.dart';
import 'placement.dart';

/// What the canvas draws for one ingredient.
class CanvasLayer {
  const CanvasLayer({
    required this.ingredientId,
    required this.imageUrls,
    required this.qty,
    required this.layerOrder,
    this.enterProfile = defaultEnterProfile,
    this.exitProfile = defaultExitProfile,
  });

  final String ingredientId;

  /// Shape variants of the same piece.
  final List<String> imageUrls;
  final int qty;
  final int layerOrder;

  /// Registered motion profile keys (ANIMATIONS.md 2-4).
  final String enterProfile;
  final String exitProfile;
}

/// Draws a product: the base image with ingredient layers ordered by
/// `layerOrder`. Knows nothing about prices, carts or categories (ARC-06).
///
/// Units present on the first frame appear without animation (defaults).
/// Each unit added later enters as a new group with its ingredient's enter
/// profile; a removed unit leaves with the exit profile, last piece first.
/// An ingredient whose strategy is a [LinePlacement] (a sauce) is drawn as
/// liquid lines instead: poured in when added, faded out when removed.
/// Ingredients whose strategy is a [JointPlacement] are laid out together:
/// those on the first frame as one batch, each unit added later around the
/// pieces already there, so no piece ever moves while the product is open.
class BuilderCanvas extends StatefulWidget {
  const BuilderCanvas({
    super.key,
    required this.baseImageUrl,
    required this.layers,
    required this.strategy,
    this.strategyByIngredient = const {},
    this.placementParams = const {},
    this.scale = 1,
    this.density = 1,
    this.piecesKey,
  });

  /// Key of the pieces' own repaint boundary (the base not included), so
  /// the orchestrator can capture them alone: a wrap shows its filling
  /// heaped from them. Same box as the canvas, before [scale].
  final GlobalKey? piecesKey;

  final String baseImageUrl;
  final List<CanvasLayer> layers;
  final PlacementStrategy strategy;

  /// Per-ingredient strategies that replace [strategy] (e.g. drizzled
  /// sauces over a band of fillings).
  final Map<String, PlacementStrategy> strategyByIngredient;
  final Map<String, num> placementParams;

  /// Visual size factor (e.g. per size option).
  final double scale;

  /// Piece count factor (larger sizes carry more pieces).
  final double density;

  @override
  State<BuilderCanvas> createState() => _BuilderCanvasState();
}

class _BuilderCanvasState extends State<BuilderCanvas> {
  /// Highest unit count ever shown per ingredient, so removed units stay
  /// mounted long enough to animate out.
  final _shownUnits = <String, int>{};
  late final Map<String, int> _initialQty = {
    for (final l in widget.layers) l.ingredientId: l.qty,
  };

  /// Sauce lines per unit, computed once (the canvas rebuilds on every
  /// change of the selection).
  final _lines = <String, List<List<({double x, double y})>>>{};

  /// Pieces per unit of the ingredients placed on their own, computed once.
  final _pieces = <String, List<PiecePlacement>>{};

  /// Ingredients laid out together, per joint strategy.
  final _joint = <JointPlacement, _JointLayout>{};

  PlacementStrategy _strategyOf(String id) =>
      widget.strategyByIngredient[id] ?? widget.strategy;

  /// Adds the units shown for the first time to their joint layouts (the
  /// first ones as a batch, later ones after them) and lays out what is new.
  void _updateJoint() {
    final added = <JointPlacement, List<PlacementUnit>>{};
    for (final l in widget.layers) {
      if (_strategyOf(l.ingredientId) case final JointPlacement s) {
        final g = _joint.putIfAbsent(s, _JointLayout.new);
        for (var u = 0; u < (_shownUnits[l.ingredientId] ?? 0); u++) {
          if (g.index.containsKey((l.ingredientId, u))) continue;
          (added[s] ??= []).add(
            PlacementUnit(
              ingredientId: l.ingredientId,
              unit: u,
              variantCount: l.imageUrls.length,
            ),
          );
        }
      }
    }
    // Same layout inputs: keep what is laid out, else lay it all out again
    // (e.g. a larger size carries more pieces).
    final key = Object.hash(
      widget.density,
      identityHashCode(widget.placementParams),
    );
    for (final MapEntry(key: s, value: g) in _joint.entries) {
      for (final u in added[s] ?? const <PlacementUnit>[]) {
        g.index[(u.ingredientId, u.unit)] = g.units.length;
        g.units.add(u);
      }
      if (g.together == 0) g.together = g.units.length;
      final keep = g.key == key ? g.pieces : const <List<PiecePlacement>>[];
      if (keep.length == g.units.length) continue;
      g.pieces = s.placeAll(
        units: g.units,
        params: widget.placementParams,
        together: g.together,
        density: widget.density,
        placed: keep,
      );
      g.key = key;
    }
  }

  List<PiecePlacement> _piecesOf(
    PlacementStrategy strategy,
    CanvasLayer layer,
    int unit,
  ) {
    if (strategy is JointPlacement) {
      final g = _joint[strategy]!;
      return g.pieces[g.index[(layer.ingredientId, unit)]!];
    }
    return _pieces.putIfAbsent(
      '${layer.ingredientId}#$unit@${widget.density}'
      '@${identityHashCode(widget.placementParams)}'
      '@${identityHashCode(strategy)}@${layer.imageUrls.length}',
      () => strategy.place(
        ingredientId: layer.ingredientId,
        unit: unit,
        variantCount: layer.imageUrls.length,
        params: widget.placementParams,
        density: widget.density,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final l in widget.layers) {
      final prev = _shownUnits[l.ingredientId] ?? 0;
      if (l.qty > prev) _shownUnits[l.ingredientId] = l.qty;
    }
    _updateJoint();
    // By layer order; layers of one order keep the order they are given.
    final layers = [
      for (final (_, l)
          in [...widget.layers.indexed]..sort((a, b) {
            final c = a.$2.layerOrder.compareTo(b.$2.layerOrder);
            return c != 0 ? c : a.$1.compareTo(b.$1);
          }))
        l,
    ];
    // A larger size draws more pieces, not bigger ones.
    final shrink = pieceShrink(widget.density);
    double pieceSizeOf(String id) =>
        (widget.placementParams['pieceSize:$id'] ??
                widget.placementParams['pieceSize'] ??
                0.14)
            .toDouble() /
        shrink;

    // Isolates canvas repaints from the surrounding controls (P1-B06).
    return RepaintBoundary(
      child: AspectRatio(
        aspectRatio: 1,
        child: AnimatedScale(
          scale: widget.scale,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          child: LayoutBuilder(
            builder: (context, box) {
              final side = box.maxWidth;
              final half = side / 2;
              final children = <Widget>[];
              for (final layer in layers) {
                final enter =
                    enterProfiles[layer.enterProfile] ??
                    enterProfiles[defaultEnterProfile]!;
                final exit =
                    exitProfiles[layer.exitProfile] ??
                    exitProfiles[defaultExitProfile]!;
                final size = side * pieceSizeOf(layer.ingredientId);
                final units = _shownUnits[layer.ingredientId] ?? 0;
                final strategy = _strategyOf(layer.ingredientId);
                if (strategy is LinePlacement) {
                  children.addAll(_sauceUnits(layer, units, strategy));
                  continue;
                }
                for (var unit = 0; unit < units; unit++) {
                  final pieces = _piecesOf(strategy, layer, unit);
                  final seed = '${layer.ingredientId}#$unit';
                  final enterDelays = staggerDelays(
                    count: pieces.length,
                    staggerMs: enter.staggerMs,
                    jitterMs: enter.jitterMs,
                    durMs: enter.durMs,
                    capMs: enter.capMs,
                    seed: seed,
                  );
                  final exitDelays = staggerDelays(
                    count: pieces.length,
                    staggerMs: exit.staggerMs,
                    jitterMs: 0,
                    durMs: exit.durMs,
                    capMs: exit.capMs,
                    seed: seed,
                  );
                  for (final (i, p) in pieces.indexed) {
                    children.add(
                      Positioned(
                        key: ValueKey('$seed#$i'),
                        left: half + p.dx * half - size / 2,
                        top: half + p.dy * half - size / 2,
                        width: size,
                        height: size,
                        child: _Piece(
                          url: layer.imageUrls[p.variant],
                          placement: p,
                          diameter: side,
                          enter: enter,
                          exit: exit,
                          enterDelay: enterDelays[i],
                          // Last piece in, first piece out.
                          exitDelay: exitDelays[pieces.length - 1 - i],
                          seed: '$seed#$i',
                          visible: unit < layer.qty,
                          animateIn:
                              unit >= (_initialQty[layer.ingredientId] ?? 0),
                        ),
                      ),
                    );
                  }
                }
              }
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      child: Image.network(
                        widget.baseImageUrl,
                        fit: BoxFit.contain,
                        // Keep the previous base on screen while a new one
                        // (another option's base) loads.
                        gaplessPlayback: true,
                        // Until the base arrives, toppings sit on a plain
                        // disc instead of floating over the page.
                        frameBuilder: (_, child, frame, sync) =>
                            frame == null && !sync ? _plainDisc : child,
                        // A missing base never breaks the screen; toppings
                        // still show on a plain disc.
                        errorBuilder: (_, _, _) => _plainDisc,
                      ),
                    ),
                  ),
                  // The pieces on a layer of their own (see piecesKey).
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: widget.piecesKey,
                      child: Stack(clipBehavior: Clip.none, children: children),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// One liquid layer per unit of a sauce, over the whole canvas.
  Iterable<Widget> _sauceUnits(
    CanvasLayer layer,
    int units,
    LinePlacement strategy,
  ) sync* {
    final id = layer.ingredientId;
    final params = widget.placementParams;
    num? param(String key) => params['$key:$id'] ?? params[key];
    final color = Color((param('color') ?? 0xFF7A3B1E).toInt());
    // Thinner at a larger size, like the pieces: it has more passes.
    final width =
        (param('lineWidth') ?? 0.03).toDouble() / pieceShrink(widget.density);
    for (var unit = 0; unit < units; unit++) {
      final seed = '$id#$unit';
      final lines = _lines.putIfAbsent(
        '$seed@${widget.density}@${identityHashCode(params)}',
        () => strategy.lines(
          ingredientId: id,
          unit: unit,
          params: params,
          density: widget.density,
        ),
      );
      yield Positioned.fill(
        key: ValueKey('$seed#sauce'),
        child: _Sauce(
          lines: lines,
          color: color,
          width: width,
          seed: seed,
          visible: unit < layer.qty,
          animateIn: unit >= (_initialQty[id] ?? 0),
        ),
      );
    }
  }
}

class _Piece extends StatefulWidget {
  const _Piece({
    required this.url,
    required this.placement,
    required this.diameter,
    required this.enter,
    required this.exit,
    required this.enterDelay,
    required this.exitDelay,
    required this.seed,
    required this.visible,
    required this.animateIn,
  });

  final String url;
  final PiecePlacement placement;
  final double diameter;
  final EnterProfile enter;
  final ExitProfile exit;
  final Duration enterDelay;
  final Duration exitDelay;
  final String seed;
  final bool visible;
  final bool animateIn;

  @override
  State<_Piece> createState() => _PieceState();
}

class _PieceState extends State<_Piece> with TickerProviderStateMixin {
  late final AnimationController _in;
  late final AnimationController _out;
  late final double _spin; // -1..1
  late final double _spread; // -1..1
  int _generation = 0;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    final rnd = StableRandom(stableSeed(widget.seed));
    _spin = rnd.nextDouble() * 2 - 1;
    _spread = rnd.nextDouble() * 2 - 1;
    _in = AnimationController(vsync: this, value: widget.animateIn ? 0 : 1);
    _out = AnimationController(vsync: this, value: widget.visible ? 0 : 1);
    if (widget.animateIn && widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playIn());
    }
  }

  @override
  void didUpdateWidget(_Piece old) {
    super.didUpdateWidget(old);
    if (old.visible && !widget.visible) _playOut();
    if (!old.visible && widget.visible) {
      _out.value = 0;
      _in.value = 0;
      _playIn();
    }
  }

  Future<void> _playIn() async {
    if (!mounted) return;
    final gen = ++_generation;
    final reduce = _reduceMotion;
    if (!reduce && widget.enterDelay > Duration.zero) {
      await Future<void>.delayed(widget.enterDelay);
    }
    if (!mounted || gen != _generation) return;
    _in.duration = Duration(milliseconds: reduce ? 120 : widget.enter.durMs);
    _in.forward(from: 0);
  }

  Future<void> _playOut() async {
    final gen = ++_generation;
    final reduce = _reduceMotion;
    if (!reduce && widget.exitDelay > Duration.zero) {
      await Future<void>.delayed(widget.exitDelay);
    }
    if (!mounted || gen != _generation) return;
    _out.duration = Duration(milliseconds: reduce ? 100 : widget.exit.durMs);
    _out.forward(from: 0);
  }

  @override
  void dispose() {
    _in.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.network(
      widget.url,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
    return AnimatedBuilder(
      animation: Listenable.merge([_in, _out]),
      child: image,
      builder: (context, child) {
        final p = widget.placement;
        final d = widget.diameter;
        final reduce = _reduceMotion;
        var opacity = 1.0, scale = p.scale, angle = p.rotation;
        var dx = 0.0, dy = 0.0;

        // Enter.
        final ti = _in.value;
        if (ti < 1) {
          final e = widget.enter;
          if (reduce) {
            opacity = ti;
          } else {
            final c = e.curve.transform(ti);
            final rest = 1 - c;
            opacity = (ti / e.fadePortion).clamp(0.0, 1.0);
            scale = p.scale * (e.fromScale + (1 - e.fromScale) * c);
            angle = p.rotation + _spin * e.spinDeg * pi / 180 * rest;
            dy = e.fromYPct / 100 * d * rest;
            dx = _spread * e.spreadPct / 100 * d * rest;
            if (e.arcPct > 0) dy -= sin(pi * ti) * e.arcPct / 100 * d;
            if (e.swayPct > 0) {
              dx += sin(ti * 2 * pi) * e.swayPct / 100 * d * rest;
            }
          }
        }

        // Exit.
        final to = _out.value;
        if (to > 0) {
          final x = widget.exit;
          final c = x.curve.transform(to);
          opacity *= 1 - to;
          if (!reduce) {
            scale *= 1 + (x.toScale - 1) * c;
            dy += x.liftPct / 100 * d * c;
            angle += x.spinDeg * pi / 180 * c;
          }
        }

        if (opacity <= 0) return const SizedBox.shrink();
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// The units a [JointPlacement] lays out on one canvas, in the order they
/// were first shown, and their pieces.
class _JointLayout {
  final units = <PlacementUnit>[];

  /// Position of (ingredient, unit) in [units].
  final index = <(String, int), int>{};

  /// How many of the first [units] were shown together (the batch).
  int together = 0;

  List<List<PiecePlacement>> pieces = const [];

  /// Layout inputs [pieces] were made with.
  Object? key;
}

/// Stand-in for the base while it loads or when it fails.
const _plainDisc = DecoratedBox(
  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE9C9A0)),
);

/// One unit of a sauce: its lines drawn as a liquid. Poured along its
/// length when added, faded out when removed; a default unit is simply there.
class _Sauce extends StatefulWidget {
  const _Sauce({
    required this.lines,
    required this.color,
    required this.width,
    required this.seed,
    required this.visible,
    required this.animateIn,
  });

  /// Polylines in normalized base coordinates (see [LinePlacement]).
  final List<List<({double x, double y})>> lines;
  final Color color;

  /// Line width as a fraction of the base radius.
  final double width;
  final String seed;
  final bool visible;
  final bool animateIn;

  @override
  State<_Sauce> createState() => _SauceState();
}

class _SauceState extends State<_Sauce> with TickerProviderStateMixin {
  late final AnimationController _pour;
  late final AnimationController _out;

  bool get _reduceMotion => MediaQuery.of(context).disableAnimations;

  @override
  void initState() {
    super.initState();
    _pour = AnimationController(vsync: this, value: widget.animateIn ? 0 : 1);
    _out = AnimationController(vsync: this, value: widget.visible ? 0 : 1);
    if (widget.animateIn && widget.visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _playIn());
    }
  }

  @override
  void didUpdateWidget(_Sauce old) {
    super.didUpdateWidget(old);
    if (old.visible && !widget.visible) _playOut();
    if (!old.visible && widget.visible) {
      _out.value = 0;
      _pour.value = 0;
      _playIn();
    }
  }

  void _playIn() {
    if (!mounted) return;
    // With reduced motion the sauce fades in whole instead of pouring.
    _pour.duration = Duration(milliseconds: _reduceMotion ? 120 : 900);
    _pour.forward(from: 0);
  }

  void _playOut() {
    _out.duration = Duration(milliseconds: _reduceMotion ? 100 : 320);
    _out.forward(from: 0);
  }

  @override
  void dispose() {
    _pour.dispose();
    _out.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_pour, _out]),
        builder: (context, _) {
          final reduce = _reduceMotion;
          final t = _pour.value;
          final progress = reduce ? 1.0 : Curves.easeInOut.transform(t);
          final opacity = (reduce ? t : 1.0) * (1 - _out.value);
          if (opacity <= 0 || progress <= 0) return const SizedBox.shrink();
          final paint = CustomPaint(
            painter: _SaucePainter(
              lines: widget.lines,
              color: widget.color,
              width: widget.width,
              progress: progress,
              seed: widget.seed,
            ),
          );
          return opacity < 1 ? Opacity(opacity: opacity, child: paint) : paint;
        },
      ),
    );
  }
}

/// Draws sauce lines as a liquid: a soft shadow on the surface beneath, a
/// rounded body (darker at its sides), and a gloss streak on the side that
/// faces the light (top left). The line swells and thins a little along its
/// length and tapers at both ends of the pour.
class _SaucePainter extends CustomPainter {
  _SaucePainter({
    required this.lines,
    required this.color,
    required this.width,
    required this.progress,
    required this.seed,
  });

  final List<List<({double x, double y})>> lines;
  final Color color;
  final double width;

  /// Poured fraction of each line's length (0..1).
  final double progress;
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final half = size.width / 2;
    final w = width * half;
    if (w <= 0) return;
    final rnd = StableRandom(stableSeed(seed));
    final shadow = Paint()
      ..color = const Color(0x4D000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.35);
    final body = Paint()
      ..color = Color.lerp(color, const Color(0xFF000000), 0.3)!;
    final top = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12);
    final gloss = Paint()
      ..color = const Color(0x8CFFFFFF)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.06);
    for (final line in lines) {
      final tube = _Tube(
        [for (final p in line) Offset(half + p.x * half, half + p.y * half)],
        width: w,
        progress: progress,
        phase: rnd.nextDouble() * 2 * pi,
      );
      if (tube.isEmpty) continue;
      canvas
        ..drawPath(tube.outline(1, shift: Offset(w * 0.12, w * 0.32)), shadow)
        ..drawPath(tube.outline(1), body)
        ..drawPath(tube.outline(0.68), top)
        ..drawPath(tube.outline(0.2, light: 0.4), gloss);
    }
  }

  @override
  bool shouldRepaint(_SaucePainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.width != width ||
      !identical(old.lines, lines);
}

/// A line of liquid along a polyline (pixels): its poured part, with a
/// half width and a normal at every point.
class _Tube {
  _Tube(
    List<Offset> points, {
    required double width,
    required double progress,
    required double phase,
  }) {
    if (points.length < 2) return;
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + (points[i] - points[i - 1]).distance);
    }
    final total = lengths.last;
    final poured = total * progress;
    for (var i = 0; i < points.length; i++) {
      if (lengths[i] <= poured) {
        _centre.add(points[i]);
        _along.add(lengths[i]);
        continue;
      }
      final f = (poured - lengths[i - 1]) / (lengths[i] - lengths[i - 1]);
      _centre.add(Offset.lerp(points[i - 1], points[i], f)!);
      _along.add(poured);
      break;
    }
    if (_centre.length < 2) return;
    double smooth(double x) {
      final t = x.clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    for (var i = 0; i < _centre.length; i++) {
      final s = _along[i];
      final swell =
          1 +
          0.14 * sin(s / width * 0.55 + phase) +
          0.07 * sin(s / width * 1.7 + 2 * phase);
      // Both ends of the whole pour taper; the tip of a pour in progress
      // stays round.
      final taper = 0.4 + 0.6 * smooth(min(s, total - s) / (width * 3));
      _halves.add(width / 2 * swell * taper);
      final a = _centre[max(0, i - 1)];
      final b = _centre[min(_centre.length - 1, i + 1)];
      final d = b - a, l = d.distance;
      _normals.add(l == 0 ? const Offset(0, 1) : Offset(-d.dy / l, d.dx / l));
    }
  }

  final _centre = <Offset>[];
  final _along = <double>[];
  final _halves = <double>[];
  final _normals = <Offset>[];

  bool get isEmpty => _centre.length < 2;

  /// The outline at [scale] of the half width, moved by [shift], and pushed
  /// towards the light by [light] of the half width (for the gloss).
  Path outline(double scale, {Offset shift = Offset.zero, double light = 0}) {
    const toLight = Offset(-0.53, -0.85);
    final centres = <Offset>[];
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < _centre.length; i++) {
      final n = _normals[i];
      final facing = n.dx * toLight.dx + n.dy * toLight.dy;
      final c = _centre[i] + shift + n * (_halves[i] * light * facing);
      final h = _halves[i] * scale;
      centres.add(c);
      left.add(c + n * h);
      right.add(c - n * h);
    }
    // Round ends: half circles ahead of the last point (dir 1) and behind
    // the first (dir -1), from one side of the line to the other.
    Iterable<Offset> cap(int i, double dir) sync* {
      final n = _normals[i], t = Offset(n.dy, -n.dx);
      final h = _halves[i] * scale * dir;
      for (var k = 1; k < 6; k++) {
        final a = pi * k / 6;
        yield centres[i] + (n * cos(a) + t * sin(a)) * h;
      }
    }

    final pts = [
      ...left,
      ...cap(_centre.length - 1, 1),
      ...right.reversed,
      ...cap(0, -1),
    ];
    Offset mid(Offset a, Offset b) => (a + b) / 2;
    final start = mid(pts.last, pts.first);
    final path = Path()..moveTo(start.dx, start.dy);
    for (var i = 0; i < pts.length; i++) {
      final p = pts[i], q = mid(p, pts[(i + 1) % pts.length]);
      path.quadraticBezierTo(p.dx, p.dy, q.dx, q.dy);
    }
    return path..close();
  }
}
