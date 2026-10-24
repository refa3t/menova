import 'dart:math';

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
};
