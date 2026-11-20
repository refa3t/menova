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
    // Pieces are drawn smaller at a larger size (pieceShrink): so are gaps.
    final minGap = (param('minGap') ?? 0.18).toDouble() / pieceShrink(density);
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
    final minGap = (param('minGap') ?? 0.14).toDouble() / pieceShrink(density);
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

/// How much smaller pieces are drawn at [density]: a larger size carries
/// more pieces of the same look, not bigger ones (the canvas itself grows
/// with the size, by the square root of [density]).
double pieceShrink(double density) => sqrt(max(density, 1e-6));

/// One quantity unit of an ingredient, as a [JointPlacement] lays it out.
class PlacementUnit {
  const PlacementUnit({
    required this.ingredientId,
    required this.unit,
    this.variantCount = 1,
  });

  final String ingredientId;

  /// 0-based quantity unit.
  final int unit;
  final int variantCount;
}

/// A strategy that lays out several ingredients together, so their pieces
/// share the surface instead of each ingredient on its own (where two
/// ingredients can land on each other).
abstract interface class JointPlacement implements PlacementStrategy {
  /// Pieces for each of [units], in the same order. The first [together]
  /// units are one batch (e.g. the product as opened), laid out the same
  /// whatever their order in the list; every later unit comes after them,
  /// in list order, around everything before it, so adding a unit never
  /// moves an earlier one. [placed] may hold the result for a prefix of
  /// [units] (same inputs, the whole batch at least): it is kept, and only
  /// the rest is laid out. Deterministic, like [PlacementStrategy.place].
  List<List<PiecePlacement>> placeAll({
    required List<PlacementUnit> units,
    required Map<String, num> params,
    int together = 0,
    double density = 1,
    List<List<PiecePlacement>> placed = const [],
  });
}

/// Even (owner request: every topping spread evenly, in harmony with the
/// others): each piece of each ingredient goes where it has the most room
/// among a few random spots (best-candidate sampling), away from the pieces
/// already there and from the edge of the area. Ingredients mix over the
/// whole surface, with alike gaps everywhere: no rings, no clusters, no
/// piece on another while there is room.
///
/// The area is the disc of `radius` around `offsetX`/`offsetY`, or only the
/// strip `bandWidth` high across it (as in [BandPlacement]). With `inset` 1
/// (the default) the pieces' edges stay inside it, with 0 their centres. A
/// piece's room is a circle of `fill` (default 0.8) of its box, `pieceSize`
/// of the base diameter as the canvas draws it.
///
/// With `coverage` set, the batch's counts (`piecesPerUnit`) are scaled
/// (by 0.5 to 1.5) so its pieces' rooms cover that share of the area: a
/// product with one topping and one with seven look alike full. Every later
/// unit takes the batch's factor.
class EvenPlacement implements JointPlacement {
  const EvenPlacement();

  /// Random spots tried per piece: more is more even, and slower.
  static const _tries = 24;

  /// How far `coverage` may scale the counts.
  static const _fewest = 0.5, _most = 1.5;

  /// The room (radius, in base radii) a piece of [ingredientId] takes at
  /// scale 1 and [density].
  static double roomOf(
    String ingredientId,
    Map<String, num> params,
    double density,
  ) {
    num? param(String key) => params['$key:$ingredientId'] ?? params[key];
    final size = (param('pieceSize') ?? 0.14).toDouble();
    final fill = (param('fill') ?? 0.8).toDouble();
    return size * fill / pieceShrink(density);
  }

  /// Pieces per unit of [ingredientId] at [density], before `coverage`.
  static int countOf(
    String ingredientId,
    Map<String, num> params,
    double density,
  ) => max(
    0,
    ((params['piecesPerUnit:$ingredientId'] ?? params['piecesPerUnit'] ?? 8) *
            density)
        .round(),
  );

  /// The unit laid out alone, as a batch of its own.
  @override
  List<PiecePlacement> place({
    required String ingredientId,
    required int unit,
    required int variantCount,
    required Map<String, num> params,
    double density = 1,
  }) => placeAll(
    units: [
      PlacementUnit(
        ingredientId: ingredientId,
        unit: unit,
        variantCount: variantCount,
      ),
    ],
    params: params,
    together: 1,
    density: density,
  ).single;

  @override
  List<List<PiecePlacement>> placeAll({
    required List<PlacementUnit> units,
    required Map<String, num> params,
    int together = 0,
    double density = 1,
    List<List<PiecePlacement>> placed = const [],
  }) {
    final area = _EvenArea(params);
    final batch = together.clamp(0, units.length);
    // A kept prefix holds the whole batch, or it is laid out again.
    final kept = min(placed.length, units.length);
    final start = kept >= batch ? kept : 0;
    final counts = [
      for (final u in units) countOf(u.ingredientId, params, density),
    ];
    final roomOfUnit = [
      for (final u in units) roomOf(u.ingredientId, params, density),
    ];
    var factor = 1.0;
    final target = params['coverage']?.toDouble();
    if (target != null && batch > 0) {
      var covered = 0.0;
      for (var i = 0; i < batch; i++) {
        covered += counts[i] * pi * roomOfUnit[i] * roomOfUnit[i];
      }
      if (covered > 0) {
        factor = (target * area.size / covered).clamp(_fewest, _most);
      }
    }
    final streams = [
      for (var i = 0; i < units.length; i++)
        _EvenStream(units[i], (counts[i] * factor).round(), roomOfUnit[i]),
    ];
    final out = [
      for (var i = 0; i < units.length; i++)
        i < start ? placed[i] : <PiecePlacement>[],
    ];
    final rooms = <_Room>[
      for (var i = 0; i < start; i++)
        for (final p in out[i]) _Room(p.dx, p.dy, streams[i].room * p.scale),
    ];

    void put(int i) {
      final (piece, room) = streams[i].next(area, rooms);
      out[i].add(piece);
      rooms.add(room);
    }

    if (start == 0 && batch > 0) {
      // The batch: larger pieces first, while there is room for them, and
      // smaller ones in the gaps; units of alike size in turn, each spread
      // over its turn by its count, so none is left only the gaps the
      // others leave. The order depends on the units, not on where they
      // are in the list.
      final shrink = pieceShrink(density);
      int sizeOf(int i) => (streams[i].room * shrink * 50).round();
      int byUnit(int a, int b) {
        final ra = streams[a].room, rb = streams[b].room;
        if (ra != rb) return rb.compareTo(ra);
        final c = units[a].ingredientId.compareTo(units[b].ingredientId);
        return c != 0 ? c : units[a].unit.compareTo(units[b].unit);
      }

      final turns =
          [
            for (var i = 0; i < batch; i++)
              for (var j = 0; j < streams[i].count; j++)
                (unit: i, at: (j + 0.5) / streams[i].count),
          ]..sort((a, b) {
            final s = sizeOf(b.unit).compareTo(sizeOf(a.unit));
            if (s != 0) return s;
            final c = a.at.compareTo(b.at);
            return c != 0 ? c : byUnit(a.unit, b.unit);
          });
      for (final t in turns) {
        put(t.unit);
      }
    }
    for (var i = max(start, batch); i < units.length; i++) {
      for (var j = 0; j < streams[i].count; j++) {
        put(i);
      }
    }
    return out;
  }
}

/// A piece's room: a circle in base radii.
class _Room {
  const _Room(this.x, this.y, this.r);

  final double x;
  final double y;
  final double r;
}

/// Where [EvenPlacement] may put pieces.
class _EvenArea {
  _EvenArea(Map<String, num> params)
    : radius = (params['radius'] ?? 0.86).toDouble(),
      band = params['bandWidth']?.toDouble(),
      inset = (params['inset'] ?? 1).toDouble(),
      ox = (params['offsetX'] ?? 0).toDouble(),
      oy = (params['offsetY'] ?? 0).toDouble();

  final double radius;
  final double? band;
  final double inset;
  final double ox;
  final double oy;

  /// The area's size, in base radii squared.
  double get size {
    if (band == null) return pi * radius * radius;
    final h = min(band!, radius);
    return 2 *
        (h * sqrt(radius * radius - h * h) +
            radius * radius * asin(h / radius));
  }

  /// How far the centre of a piece of room [r] may be from the middle, and
  /// from the strip's middle line.
  double _disc(double r) => max(0.0, radius - inset * r);
  double _strip(double r) => max(0.0, band! - inset * r);

  /// Distance from (x, y) to the nearest edge for a piece of room [r].
  double clearance(double x, double y, double r) {
    final dx = x - ox, dy = y - oy;
    var c = _disc(r) - sqrt(dx * dx + dy * dy);
    if (band != null) c = min(c, _strip(r) - dy.abs());
    return c;
  }

  /// A uniform random spot for the centre of a piece of room [r].
  (double, double) sample(StableRandom rnd, double r) {
    final l = _disc(r);
    if (band == null) {
      final d = l * sqrt(rnd.nextDouble());
      final a = rnd.nextDouble() * 2 * pi;
      return (ox + d * cos(a), oy + d * sin(a));
    }
    final h = min(_strip(r), l);
    for (var k = 0; k < 8; k++) {
      final x = (rnd.nextDouble() * 2 - 1) * l;
      final y = (rnd.nextDouble() * 2 - 1) * h;
      if (x * x + y * y <= l * l) return (ox + x, oy + y);
    }
    return (ox, oy);
  }
}

/// One unit's pieces for [EvenPlacement], from its own random sequence (the
/// same whatever else is on the surface).
class _EvenStream {
  _EvenStream(PlacementUnit u, this.count, this.room)
    : _rnd = StableRandom(stableSeed('${u.ingredientId}#even#${u.unit}')),
      _variants = u.variantCount;

  final StableRandom _rnd;
  final int _variants;
  final int count;
  final double room;

  /// The next piece: the spot with the most room out of a few tries,
  /// counting the area's edge as a piece mirrored across it.
  (PiecePlacement, _Room) next(_EvenArea area, List<_Room> rooms) {
    final scale = 0.9 + _rnd.nextDouble() * 0.2;
    final rotation = _rnd.nextDouble() * 2 * pi;
    final variant = _variants <= 1 ? 0 : _rnd.nextInt(_variants);
    final r = room * scale;
    var best = double.negativeInfinity, bx = area.ox, by = area.oy;
    for (var k = 0; k < EvenPlacement._tries; k++) {
      final (x, y) = area.sample(_rnd, r);
      var score = 2 * area.clearance(x, y, r);
      if (score <= best) continue;
      for (final o in rooms) {
        final dx = x - o.x, dy = y - o.y;
        final gap = sqrt(dx * dx + dy * dy) - r - o.r;
        if (gap < score) {
          score = gap;
          if (score <= best) break;
        }
      }
      if (score > best) {
        best = score;
        bx = x;
        by = y;
      }
    }
    return (
      PiecePlacement(
        dx: bx,
        dy: by,
        rotation: rotation,
        scale: scale,
        variant: variant,
      ),
      _Room(bx, by, r),
    );
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
/// Every extra unit pours its passes between the earlier ones. Every point
/// of the stroke, turns included, stays on that area: the stroke starts and
/// ends at the area's edge, and a pass stops short of the edge only by the
/// room its turn takes there. It places no pieces: the canvas draws the
/// lines as a liquid in the sauce's `color`.
class SaucePlacement implements LinePlacement {
  const SaucePlacement();

  /// Where a unit's passes sit, as a fraction of the spacing: unit 0 in the
  /// middle of each slot, unit 1 between unit 0's passes, then quarters.
  static const _slots = [0.5, 0.0, 0.25, 0.75, 0.125, 0.625, 0.375, 0.875];

  /// Where a unit pours whose slot falls on the area's edges only (one pass
  /// a unit): this fraction of the spacing inside each edge, clear of the
  /// passes of units 0, 2 and 3.
  static const _edgeSlot = 0.125;

  /// A turn's handles, as a share of the distance between the ends it joins
  /// (about a half circle).
  static const _round = 0.6;

  /// The shortest pass poured, and how far a pass's wave fades out towards
  /// a turn, so the turn leaves along the pass.
  static const _minPass = 0.04, _fade = 0.08;

  /// The step between a pass's points, and its wave's frequency.
  static const _step = 0.02, _freq = 17.0;

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
    final ox = (param('offsetX') ?? 0).toDouble();
    final oy = (param('offsetY') ?? 0).toDouble();
    final wave = (param('wave') ?? 0.02).toDouble().abs();
    final degrees =
        param('angle')?.toDouble() ??
        (stableSeed('$ingredientId#angle') % 90 - 45).toDouble();
    final area = _SauceArea(
      (param('radius') ?? 0.78).toDouble(),
      param('bandWidth')?.toDouble(),
      degrees * pi / 180,
    );
    final (lo, hi) = area.across;
    final spacing = (hi - lo) / count;
    if (spacing <= 0) return const [];

    // The unit's passes: at its slot of every spacing inside the area. A
    // unit whose slot falls on the edges only (one pass a unit) pours just
    // inside them instead.
    final slot = _slots[unit % _slots.length];
    final offsets = [
      for (var l = 0; l <= count; l++) (l, lo + spacing * (l + slot)),
    ]..removeWhere((o) => o.$2 <= lo + 1e-9 || o.$2 >= hi - 1e-9);
    if (offsets.isEmpty) {
      offsets.addAll([
        (0, lo + spacing * _edgeSlot),
        (count, hi - spacing * _edgeSlot),
      ]);
    }
    // Each pass's part on the area, with room for its wave.
    var passes = [
      for (final (l, s) in offsets)
        if (area.chord(s, margin: wave) case (
          final t0,
          final t1,
        ) when t1 - t0 >= _minPass)
          _Pass(l, s, t0, t1),
    ];

    // Back and forth: pass k runs up t when k is even, down when odd, so
    // turn k joins passes k and k + 1 at their high ends when k is even,
    // at their low ends when odd. An end pass too short to hold a round
    // turn is left out.
    int sideOf(int k) => k.isEven ? 1 : -1;
    bool holds(int k, _Pass end) {
      final side = sideOf(k);
      final turn = _turn(passes[k], passes[k + 1], side, _round);
      final cut = _cut(area, turn, side);
      return cut != null && cut <= end.length - _minPass;
    }

    while (passes.length > 1) {
      if (!holds(0, passes.first)) {
        passes = passes.sublist(1);
      } else if (!holds(passes.length - 2, passes.last)) {
        passes = passes.sublist(0, passes.length - 1);
      } else {
        break;
      }
    }
    if (passes.isEmpty) return const [];

    // Each turn as round as fits; a middle pass shares what it can spare
    // between its two turns.
    final last = passes.length - 1;
    double spare(int k) =>
        (passes[k].length - _minPass) / (k == 0 || k == last ? 1 : 2);
    final turns = [
      for (var k = 0; k < last; k++)
        _fit(
          area,
          passes[k],
          passes[k + 1],
          sideOf(k),
          min(spare(k), spare(k + 1)),
        ),
    ];

    // One stroke: each pass, cut back where a turn joins it, then its turn.
    final phase = (stableSeed('$ingredientId#wave#$unit') % 628) / 100;
    final points = <(double, double)>[];
    for (var k = 0; k <= last; k++) {
      final p = passes[k];
      final into = k > 0 ? turns[k - 1].cut : 0.0;
      final out = k < last ? turns[k].cut : 0.0;
      final (from, to) = sideOf(k) > 0
          ? (p.t0 + into, p.t1 - out)
          : (p.t1 - into, p.t0 + out);
      final n = max(2, ((to - from).abs() / _step).ceil());
      for (var i = 0; i <= n; i++) {
        final t = from + (to - from) * i / n;
        final fade =
            (k > 0 ? _ease((t - from).abs() / _fade) : 1.0) *
            (k < last ? _ease((to - t).abs() / _fade) : 1.0);
        points.add((t, p.s + wave * fade * sin(_freq * t + phase + p.l)));
      }
      if (k < last) points.addAll(turns[k].points);
    }
    return [
      [
        for (final (t, w) in points)
          (
            x: ox + area.dx * t + area.nx * w,
            y: oy + area.dy * t + area.ny * w,
          ),
      ],
    ];
  }

  /// Smoothstep: 0 at 0, 1 from 1 on, flat at both.
  static double _ease(double x) => x >= 1 ? 1 : x * x * (3 - 2 * x);

  /// The rounded turn joining [a]'s end to [b]'s start on [side] (1: their
  /// high ends, -1: their low ends): a cubic leaving along [a] and coming
  /// back along [b], its handles [round] of the distance between the ends.
  /// Its points, ends left out, as (t, w) in the passes' frame.
  static List<(double, double)> _turn(
    _Pass a,
    _Pass b,
    int side,
    double round,
  ) {
    final e0 = a.end(side), e1 = b.end(side);
    final de = e1 - e0, ds = b.s - a.s;
    final gap = sqrt(de * de + ds * ds);
    final h = side * round * gap;
    // About 0.03 apart, and at least ten steps.
    final n = max(10, (gap / 0.03).ceil());
    return [
      for (var i = 1; i < n; i++)
        () {
          final t = i / n, u = 1 - t;
          final b0 = u * u * u, b1 = 3 * u * u * t, b2 = 3 * u * t * t;
          final b3 = t * t * t;
          return (
            b0 * e0 + b1 * (e0 + h) + b2 * (e1 + h) + b3 * e1,
            (b0 + b1) * a.s + (b2 + b3) * b.s,
          );
        }(),
    ];
  }

  /// How far both passes must stop short of their ends on [side] for
  /// [turn] (as [_turn] gives it) to stay on [area]; null when no cut
  /// does.
  static double? _cut(_SauceArea area, List<(double, double)> turn, int side) {
    final chords = <(double, double)>[];
    var cut = 0.0;
    for (final (t, w) in turn) {
      final chord = area.chord(w);
      if (chord == null) return null;
      chords.add(chord);
      cut = max(cut, side > 0 ? t - chord.$2 : chord.$1 - t);
    }
    // Cut back that far, no point may leave the area at the other end.
    for (final (i, (t, _)) in turn.indexed) {
      final (t0, t1) = chords[i];
      if (side > 0 ? t - cut < t0 : t + cut > t1) return null;
    }
    return cut;
  }

  /// The roundest turn joining [a] to [b] on [side] that stays on [area]
  /// with both passes cut back by at most [cap]: its points, moved in by
  /// the cut, and the cut. A flatter turn needs less room; the flattest, a
  /// straight join of two points on the area, needs none.
  static ({List<(double, double)> points, double cut}) _fit(
    _SauceArea area,
    _Pass a,
    _Pass b,
    int side,
    double cap,
  ) {
    bool fits(double round) =>
        (_cut(area, _turn(a, b, side, round), side) ?? double.infinity) <= cap;
    var round = _round;
    if (!fits(round)) {
      var flat = 0.0, high = _round;
      for (var i = 0; i < 24; i++) {
        final mid = (flat + high) / 2;
        if (fits(mid)) {
          flat = mid;
        } else {
          high = mid;
        }
      }
      round = flat;
    }
    final turn = _turn(a, b, side, round);
    final cut = _cut(area, turn, side) ?? 0;
    return (points: [for (final (t, w) in turn) (t - side * cut, w)], cut: cut);
  }
}

/// Where a [SaucePlacement] pours, in its passes' frame: t along the passes
/// and w across them, from the area's centre. The disc of [radius], or its
/// part in the strip [band] high (as in [BandPlacement]).
class _SauceArea {
  _SauceArea(this.radius, this.band, double angle)
    : dx = cos(angle),
      dy = sin(angle),
      nx = -sin(angle),
      ny = cos(angle);

  final double radius;
  final double? band;

  /// Along a pass (dx, dy), and across the passes (nx, ny).
  final double dx, dy, nx, ny;

  double get _half => min(band ?? radius, radius);

  /// The area's extent across the passes: its extreme points are the disc's
  /// own (when inside the strip) or the strip's corners on the rim.
  (double, double) get across {
    final half = _half;
    final corner = sqrt(max(0.0, radius * radius - half * half));
    final ends = [
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
    return (ends.reduce(min), ends.reduce(max));
  }

  /// The part of the line [w] across on the area, as an interval of t
  /// (null when it misses), such that points up to [margin] off the line
  /// are on the area too.
  (double, double)? chord(double w, {double margin = 0}) {
    final off = w.abs() + margin;
    if (off >= radius) return null;
    final r = sqrt(radius * radius - off * off);
    var t0 = -r, t1 = r;
    if (band != null) {
      // The strip: |w * ny + t * dy| <= half.
      final half = _half - margin * ny.abs();
      if (dy.abs() < 1e-9) {
        if ((w * ny).abs() > half) return null;
      } else {
        final p = (-half - w * ny) / dy, q = (half - w * ny) / dy;
        t0 = max(t0, min(p, q));
        t1 = min(t1, max(p, q));
      }
    }
    return t1 > t0 ? (t0, t1) : null;
  }
}

/// A pass of a [SaucePlacement] stroke, in its frame (see [_SauceArea]):
/// slot [l] of the spacing, [s] across, on the area from [t0] to [t1].
class _Pass {
  const _Pass(this.l, this.s, this.t0, this.t1);

  final int l;
  final double s;
  final double t0;
  final double t1;

  double get length => t1 - t0;

  /// Its end on [side]: 1 the high end, -1 the low end.
  double end(int side) => side > 0 ? t1 : t0;
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
  'even': EvenPlacement(),
};

/// The registered strategies a definition assigns to single ingredients
/// (`placement.byIngredient`); unknown keys are left out (the validator
/// rejects them first).
Map<String, PlacementStrategy> strategiesByIngredient(PlacementSpec spec) => {
  for (final e in spec.byIngredient.entries)
    e.key: ?placementStrategies[e.value],
};
