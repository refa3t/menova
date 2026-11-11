import 'dart:math';

import 'package:core/core.dart';

/// One piece of an ingredient on the canvas, in normalized base coordinates:
/// (0,0) is the base center, radius 1 is the base edge.
class PiecePlacement {
  const PiecePlacement({
    required this.dx,
    required this.dy,
    required this.rotation,
    required this.scale,
    required this.variant,
  });

  final double dx;
  final double dy;

  /// Radians.
  final double rotation;
  final double scale;

  /// Index into the ingredient's shape variants.
  final int variant;
}

/// Extension point (P1-B07): decides where an ingredient unit's pieces go.
abstract interface class PlacementStrategy {
  /// Pieces for quantity unit [unit] (0-based) of [ingredientId]. Must be
  /// deterministic: same inputs, same output, on every rebuild and platform.
  /// [density] multiplies the piece count (e.g. larger sizes get more).
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  });
}

/// Scatter (CLAUDE.md 4.3): a fixed seed derived from the ingredient id, and a
/// different seed per extra unit so extras never cover the default pieces.
class ScatterPlacement implements PlacementStrategy {
  const ScatterPlacement();

  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) {
    // Per-ingredient overrides use keys like `piecesPerUnit:<ingredientId>`.
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final count = ((param('piecesPerUnit') ?? 8) * density).round();
    final radius = (param('radius') ?? 0.78).toDouble();
    final minGap = (param('minGap') ?? 0.18).toDouble();
    final rnd = StableRandom(stableSeed('$ingredientId#$unit'));
    final pieces = <PiecePlacement>[];
    var attempts = 0;
    while (pieces.length < count && attempts < count * 40) {
      attempts++;
      // Uniform over the disc.
      final r = radius * sqrt(rnd.nextDouble());
      final a = rnd.nextDouble() * 2 * pi;
      final x = r * cos(a), y = r * sin(a);
      // Relax the gap as attempts grow so dense layers still fill.
      final gap = minGap * (1 - attempts / (count * 40));
      if (pieces.any((p) => _dist(p.dx, p.dy, x, y) < gap)) continue;
      pieces.add(
        PiecePlacement(
          dx: x,
          dy: y,
          rotation: rnd.nextDouble() * 2 * pi,
          scale: 0.85 + rnd.nextDouble() * 0.3,
          variant: variantCount <= 1 ? 0 : rnd.nextInt(variantCount),
        ),
      );
    }
    return pieces;
  }

  static double _dist(double x1, double y1, double x2, double y2) =>
      sqrt((x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2));
}

/// Rings: pieces evenly spread on concentric, evenly spaced rings, each ring's
/// count proportional to its circumference. Every ingredient gets its own
/// angular offset so ingredients interleave, and each extra unit is rotated
/// and nudged radially so it never sits on the previous unit.
class RingsPlacement implements PlacementStrategy {
  const RingsPlacement();

  static const _golden = 2.399963229728653; // radians

  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) {
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final count = ((param('piecesPerUnit') ?? 8) * density).round();
    if (count <= 0) return const [];
    final radius = (param('radius') ?? 0.74).toDouble();
    final rings = max(1, (sqrt(count / 3)).round());

    // Evenly spaced rings, the outermost on the allowed radius and the
    // innermost near the center; counts follow circumference so density is
    // uniform across the disc.
    final radii = [
      for (var k = 0; k < rings; k++) radius * (k + 0.75) / (rings - 0.25),
    ];
    final total = radii.fold<double>(0, (s, r) => s + r);
    final counts = [for (final r in radii) (count * r / total).floor()];
    var missing = count - counts.fold<int>(0, (s, c) => s + c);
    for (var k = rings - 1; missing > 0; k = (k - 1) % rings, missing--) {
      counts[k]++;
    }

    final rnd = StableRandom(stableSeed('$ingredientId#$unit'));
    final idOffset = (stableSeed(ingredientId) % 3600) / 3600 * 2 * pi;
    // Extra units shift radially inward/outward alternately.
    final ringGap = radius / rings;
    final radialNudge = unit == 0 ? 0.0 : (unit.isOdd ? -0.3 : 0.3) * ringGap;

    final pieces = <PiecePlacement>[];
    for (var k = 0; k < rings; k++) {
      final n = counts[k];
      if (n == 0) continue;
      final step = 2 * pi / n;
      final start = idOffset + k * _golden + unit * (step / 2 + 0.37);
      final r = (radii[k] + radialNudge).clamp(0.0, radius);
      for (var i = 0; i < n; i++) {
        final a = start + i * step;
        pieces.add(
          PiecePlacement(
            dx: r * cos(a),
            dy: r * sin(a),
            rotation: rnd.nextDouble() * 2 * pi,
            scale: 0.95 + rnd.nextDouble() * 0.1,
            variant: variantCount <= 1 ? 0 : rnd.nextInt(variantCount),
          ),
        );
      }
    }
    return pieces;
  }
}

/// Band (P2-04): pieces fill a horizontal strip across the middle, where a
/// crepe's filling sits before folding. `bandWidth` is the strip height as a
/// fraction of the diameter; pieces stay inside `radius`. Extra units use
/// their own seed, so they land between the default pieces.
class BandPlacement implements PlacementStrategy {
  const BandPlacement();

  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) {
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final count = ((param('piecesPerUnit') ?? 8) * density).round();
    final radius = (param('radius') ?? 0.8).toDouble();
    final half = (param('bandWidth') ?? 0.42).toDouble(); // of the diameter
    final minGap = (param('minGap') ?? 0.14).toDouble();
    // Optional centre of the strip (e.g. the middle of a half-moon base).
    final ox = (param('offsetX') ?? 0).toDouble();
    final oy = (param('offsetY') ?? 0).toDouble();
    final rnd = StableRandom(stableSeed('$ingredientId#band#$unit'));
    final pieces = <PiecePlacement>[];
    var attempts = 0;
    while (pieces.length < count && attempts < count * 40) {
      attempts++;
      final y = (rnd.nextDouble() * 2 - 1) * half;
      final span = sqrt(max(0.0, radius * radius - y * y));
      final x = (rnd.nextDouble() * 2 - 1) * span;
      final gap = minGap * (1 - attempts / (count * 40));
      if (pieces.any(
        (p) => ScatterPlacement._dist(p.dx - ox, p.dy - oy, x, y) < gap,
      )) {
        continue;
      }
      pieces.add(
        PiecePlacement(
          dx: x + ox,
          dy: y + oy,
          rotation: rnd.nextDouble() * 2 * pi,
          scale: 0.85 + rnd.nextDouble() * 0.3,
          variant: variantCount <= 1 ? 0 : rnd.nextInt(variantCount),
        ),
      );
    }
    return pieces;
  }
}

/// Drizzle (P2-04): pieces follow gentle wavy lines across the surface, each
/// piece turned along its line, like a sauce poured from a bottle. `lines`
/// sets how many lines one unit draws, `wave` their amplitude; each extra
/// unit draws its lines between the previous ones.
class DrizzlePlacement implements PlacementStrategy {
  const DrizzlePlacement();

  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) {
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final count = ((param('piecesPerUnit') ?? 12) * density).round();
    final lines = max(1, (param('lines') ?? 3).round());
    if (count <= 0) return const [];
    final radius = (param('radius') ?? 0.78).toDouble();
    final wave = (param('wave') ?? 0.07).toDouble();
    final ox = (param('offsetX') ?? 0).toDouble();
    final oy = (param('offsetY') ?? 0).toDouble();
    final rnd = StableRandom(stableSeed('$ingredientId#drizzle#$unit'));
    // Lines spread over the disc; extra units sit half a spacing apart.
    final spacing = 2 * radius / (lines + 1);
    // Each ingredient gets its own stable offset, so two sauces interleave
    // instead of covering each other; extra units sit between earlier lines.
    final own =
        ((stableSeed('$ingredientId#lines') % 1000) / 1000 - 0.5) *
        spacing *
        0.9;
    final shift = own + unit * spacing / (unit + 1);
    final perLine = max(2, (count / lines).round());
    final phase = (stableSeed(ingredientId) % 628) / 100;
    final pieces = <PiecePlacement>[];
    for (var l = 0; l < lines; l++) {
      final y0 = -radius + spacing * (l + 1) + shift - spacing / 2;
      // Leave room for the wave so no piece crosses the edge.
      final yMax = min(radius, y0.abs() + wave);
      final span = sqrt(max(0.0, radius * radius - yMax * yMax)) * 0.92;
      for (var i = 0; i < perLine; i++) {
        final t = perLine == 1 ? 0.5 : i / (perLine - 1);
        final x = -span + 2 * span * t;
        const freq = 7.0;
        final y = y0 + wave * sin(freq * x + phase + l);
        final slope = wave * freq * cos(freq * x + phase + l);
        pieces.add(
          PiecePlacement(
            dx: x + ox,
            dy: y + oy,
            rotation: atan(slope),
            scale: 0.9 + rnd.nextDouble() * 0.2,
            variant: variantCount <= 1 ? 0 : rnd.nextInt(variantCount),
          ),
        );
      }
    }
    return pieces;
  }
}

/// A strategy whose ingredient is drawn as lines rather than pieces: a
/// liquid (sauce). The canvas draws each polyline, in normalized base
/// coordinates like [PiecePlacement].
abstract interface class LinePlacement implements PlacementStrategy {
  /// The lines of quantity unit [unit] (0-based) of [ingredientId].
  /// Deterministic, like [PlacementStrategy.place].
  List<List<({double x, double y})>> lines({
    required String ingredientId,
    required int unit,
    required Map<String, num> params,
    double density = 1,
  });
}

/// Sauce (owner request: liquid, evenly spread, not lumps): each unit is
/// poured as one continuous zigzag, like a squeeze bottle drawn back and
/// forth: `lines` evenly spaced, gently wavy passes (`wave`) across the
/// whole surface (the disc of `radius`, or only the strip `bandWidth` high,
/// as in [BandPlacement]), joined by rounded turns and tilted by `angle`
/// degrees (each sauce its own angle by default, so two sauces cross).
/// Every extra unit pours its passes between the earlier ones. It places no
/// pieces: the canvas draws the lines as a liquid in the sauce's `color`.
class SaucePlacement implements LinePlacement {
  const SaucePlacement();

  /// Where a unit's passes sit, as a fraction of the spacing: unit 0 in the
  /// middle of each slot, unit 1 between unit 0's passes, then quarters.
  static const _slots = [0.5, 0.0, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875];

  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) => const [];

  @override
  List<List<({double x, double y})>> lines({
    required String ingredientId,
    required int unit,
    required Map<String, num> params,
    double density = 1,
  }) {
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    // The spacing is a length: a larger size (more area) keeps it with
    // sqrt(density) more passes.
    final count = max(1, ((param('lines') ?? 4) * sqrt(density)).round());
    final radius = (param('radius') ?? 0.78).toDouble();
    final band = param('bandWidth')?.toDouble();
    final half = band == null ? radius : min(band, radius);
    final ox = (param('offsetX') ?? 0).toDouble();
    final oy = (param('offsetY') ?? 0).toDouble();
    final wave = (param('wave') ?? 0.02).toDouble();
    final degrees =
        param('angle')?.toDouble() ??
        (stableSeed('$ingredientId#angle') % 90 - 45).toDouble();
    final a = degrees * pi / 180;
    final dx = cos(a), dy = sin(a); // along a pass
    final nx = -sin(a), ny = cos(a); // across the passes

    // The region's extent across the passes: its extreme points are the
    // disc's own (when inside the strip) or the strip's corners on the rim.
    final corner = sqrt(max(0.0, radius * radius - half * half));
    final across = [
      for (final sign in const [-1.0, 1.0])
        if ((sign * radius * ny).abs() <= half + 1e-9) sign * radius,
      for (final (x, y) in [
        (corner, half),
        (-corner, half),
        (corner, -half),
        (-corner, -half),
      ])
        x * nx + y * ny,
    ];
    final lo = across.reduce(min), hi = across.reduce(max);
    final spacing = (hi - lo) / count;
    if (spacing <= 0) return const [];

    // The part of the pass at offset [s] inside the region, as an interval
    // of t along it (empty when it misses), short of the edge by the room
    // its rounded turn takes, so the turns stay on the surface too.
    final room = 0.45 * spacing;
    (double, double)? span(double s) {
      if (s.abs() >= radius) return null;
      final r = sqrt(radius * radius - s * s);
      var t0 = -r, t1 = r;
      // The strip: |s * ny + t * dy| <= half.
      if (dy.abs() < 1e-9) {
        if ((s * ny).abs() > half) return null;
      } else {
        final p = (-half - s * ny) / dy, q = (half - s * ny) / dy;
        t0 = max(t0, min(p, q));
        t1 = min(t1, max(p, q));
      }
      t0 += room;
      t1 -= room;
      return t1 - t0 > 0.04 ? (t0, t1) : null;
    }

    final slot = _slots[unit % _slots.length];
    final phase = (stableSeed('$ingredientId#wave#$unit') % 628) / 100;
    const step = 0.02, freq = 17.0;
    final passes = <List<({double x, double y})>>[];
    for (var l = 0; l <= count; l++) {
      final s = lo + spacing * (l + slot);
      if (s <= lo + 1e-9 || s >= hi - 1e-9) continue;
      final interval = span(s);
      if (interval == null) continue;
      final (t0, t1) = interval;
      final n = max(2, ((t1 - t0) / step).ceil());
      final pass = [
        for (var i = 0; i <= n; i++)
          () {
            final t = t0 + (t1 - t0) * i / n;
            final w = s + wave * sin(freq * t + phase + l);
            return (x: dx * t + nx * w + ox, y: dy * t + ny * w + oy);
          }(),
      ];
      // Back and forth: every other pass runs the other way.
      passes.add(passes.length.isOdd ? pass.reversed.toList() : pass);
    }
    if (passes.isEmpty) return const [];

    // One stroke: each pass joined to the next by a rounded turn (a cubic
    // leaving along the pass and coming back the other way).
    final stroke = [...passes.first];
    for (final pass in passes.skip(1)) {
      final p0 = stroke.last, p3 = pass.first;
      final prev = stroke[stroke.length - 2];
      final ux = p0.x - prev.x, uy = p0.y - prev.y;
      final ul = sqrt(ux * ux + uy * uy);
      final gap = sqrt(pow(p3.x - p0.x, 2) + pow(p3.y - p0.y, 2));
      final k = 0.6 * gap / (ul == 0 ? 1 : ul);
      final p1 = (x: p0.x + ux * k, y: p0.y + uy * k);
      final p2 = (x: p3.x + ux * k, y: p3.y + uy * k);
      for (var i = 1; i < 10; i++) {
        final t = i / 10, u = 1 - t;
        final b0 = u * u * u, b1 = 3 * u * u * t, b2 = 3 * u * t * t;
        final b3 = t * t * t;
        stroke.add((
          x: b0 * p0.x + b1 * p1.x + b2 * p2.x + b3 * p3.x,
          y: b0 * p0.y + b1 * p1.y + b2 * p2.y + b3 * p3.y,
        ));
      }
      stroke.addAll(pass);
    }
    return [stroke];
  }
}

/// Small deterministic PRNG (mulberry32). `dart:math` Random is not
/// guaranteed identical across VM and web, and on web its first outputs are
/// correlated for nearby seeds, which made pieces line up in a band.
class StableRandom {
  StableRandom(int seed) : _state = seed & 0xffffffff;

  int _state;

  double nextDouble() {
    _state = (_state + 0x6d2b79f5) & 0xffffffff;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= t + _imul(t ^ (t >>> 7), t | 61);
    t &= 0xffffffff;
    return ((t ^ (t >>> 14)) & 0xffffffff) / 4294967296;
  }

  int nextInt(int max) => (nextDouble() * max).floor();

  /// 32-bit multiply that behaves the same on VM and web.
  static int _imul(int a, int b) {
    final aHi = (a >>> 16) & 0xffff, aLo = a & 0xffff;
    final bHi = (b >>> 16) & 0xffff, bLo = b & 0xffff;
    return (aLo * bLo + (((aHi * bLo + aLo * bHi) << 16) & 0xffffffff)) &
        0xffffffff;
  }
}

/// FNV-1a 32-bit: stable across platforms, unlike `String.hashCode`.
int stableSeed(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = StableRandom._imul(h, 0x01000193);
  }
  return h;
}

/// Registered placement strategies, resolved by the key in the definition.
const placementStrategies = <String, PlacementStrategy>{
  'scatter': ScatterPlacement(),
  'rings': RingsPlacement(),
  'band': BandPlacement(),
  'drizzle': DrizzlePlacement(),
  'sauce': SaucePlacement(),
};

/// The registered strategies a definition assigns to single ingredients
/// (`placement.byIngredient`); unknown keys are left out (the validator
/// rejects them first).
Map<String, PlacementStrategy> strategiesByIngredient(PlacementSpec spec) => {
  for (final e in spec.byIngredient.entries)
    e.key: ?placementStrategies[e.value],
};
