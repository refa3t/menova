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
  });

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

  @override
  Widget build(BuildContext context) {
    for (final l in widget.layers) {
      final prev = _shownUnits[l.ingredientId] ?? 0;
      if (l.qty > prev) _shownUnits[l.ingredientId] = l.qty;
    }
    final layers = [...widget.layers]
      ..sort((a, b) => a.layerOrder.compareTo(b.layerOrder));
    double pieceSizeOf(String id) =>
        (widget.placementParams['pieceSize:$id'] ??
                widget.placementParams['pieceSize'] ??
                0.14)
            .toDouble();

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
              final children = <Widget>[
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
              ];
              for (final layer in layers) {
                final enter =
                    enterProfiles[layer.enterProfile] ??
                    enterProfiles[defaultEnterProfile]!;
                final exit =
                    exitProfiles[layer.exitProfile] ??
                    exitProfiles[defaultExitProfile]!;
                final size = side * pieceSizeOf(layer.ingredientId);
                final units = _shownUnits[layer.ingredientId] ?? 0;
                for (var unit = 0; unit < units; unit++) {
                  final strategy =
                      widget.strategyByIngredient[layer.ingredientId] ??
                      widget.strategy;
                  final pieces = strategy.place(
                    ingredientId: layer.ingredientId,
                    unit: unit,
                    variantCount: layer.imageUrls.length,
                    params: widget.placementParams,
                    density: widget.density,
                  );
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
              return Stack(clipBehavior: Clip.none, children: children);
            },
          ),
        ),
      ),
    );
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

/// Stand-in for the base while it loads or when it fails.
const _plainDisc = DecoratedBox(
  decoration: BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE9C9A0)),
);
