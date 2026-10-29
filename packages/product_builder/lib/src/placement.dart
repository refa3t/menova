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
};

/// The registered strategies a definition assigns to single ingredients
/// (`placement.byIngredient`); unknown keys are left out (the validator
/// rejects them first).
Map<String, PlacementStrategy> strategiesByIngredient(PlacementSpec spec) => {
  for (final e in spec.byIngredient.entries)
    e.key: ?placementStrategies[e.value],
};
