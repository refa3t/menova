import 'package:flutter/material.dart';

import 'placement.dart';

/// What the canvas draws for one ingredient.
class CanvasLayer {
  const CanvasLayer({
    required this.ingredientId,
    required this.imageUrls,
    required this.qty,
    required this.layerOrder,
  });

  final String ingredientId;

  /// Shape variants of the same piece.
  final List<String> imageUrls;
  final int qty;
  final int layerOrder;
}

/// Draws a product: the base image with ingredient layers ordered by
/// `layerOrder`. Knows nothing about prices, carts or categories (ARC-06).
///
/// Units present on the first frame appear without animation (defaults);
/// units added later drop in and fade, removed units fade and shrink.
class BuilderCanvas extends StatefulWidget {
  const BuilderCanvas({
    super.key,
    required this.baseImageUrl,
    required this.layers,
    required this.strategy,
    this.placementParams = const {},
    this.scale = 1,
  });

  final String baseImageUrl;
  final List<CanvasLayer> layers;
  final PlacementStrategy strategy;
  final Map<String, num> placementParams;

  /// Visual size factor (e.g. per size option).
  final double scale;

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

    return AspectRatio(
      aspectRatio: 1,
      child: AnimatedScale(
        scale: widget.scale,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: LayoutBuilder(
          builder: (context, box) {
            final side = box.maxWidth;
            final half = side / 2;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: Image.network(
                    widget.baseImageUrl,
                    fit: BoxFit.contain,
                  ),
                ),
                for (final layer in layers)
                  for (
                    var unit = 0;
                    unit < (_shownUnits[layer.ingredientId] ?? 0);
                    unit++
                  )
                    for (final p in widget.strategy.place(
                      ingredientId: layer.ingredientId,
                      unit: unit,
                      variantCount: layer.imageUrls.length,
                      params: widget.placementParams,
                    ))
                      Positioned(
                        key: ValueKey('${layer.ingredientId}#$unit#${p.dx}'),
                        left:
                            half +
                            p.dx * half -
                            side * pieceSizeOf(layer.ingredientId) / 2,
                        top:
                            half +
                            p.dy * half -
                            side * pieceSizeOf(layer.ingredientId) / 2,
                        width: side * pieceSizeOf(layer.ingredientId),
                        height: side * pieceSizeOf(layer.ingredientId),
                        child: _Piece(
                          url: layer.imageUrls[p.variant],
                          rotation: p.rotation,
                          scale: p.scale,
                          visible: unit < layer.qty,
                          animateIn:
                              unit >= (_initialQty[layer.ingredientId] ?? 0),
                        ),
                      ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Piece extends StatelessWidget {
  const _Piece({
    required this.url,
    required this.rotation,
    required this.scale,
    required this.visible,
    required this.animateIn,
  });

  final String url;
  final double rotation;
  final double scale;
  final bool visible;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final image = Transform.rotate(
      angle: rotation,
      child: Image.network(url, fit: BoxFit.contain),
    );
    // Remove: fade + shrink.
    final out = AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 220),
      child: AnimatedScale(
        scale: visible ? scale : scale * 0.4,
        duration: const Duration(milliseconds: 220),
        child: image,
      ),
    );
    if (!animateIn || reduceMotion) return out;
    // Add: drop from above + fade in, once on mount.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -40),
          child: child,
        ),
      ),
      child: out,
    );
  }
}
