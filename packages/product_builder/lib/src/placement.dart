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
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
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
  }) {
    // Per-ingredient overrides use keys like `piecesPerUnit:<ingredientId>`.
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final count = (param('piecesPerUnit') ?? 8).toInt();
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
};
