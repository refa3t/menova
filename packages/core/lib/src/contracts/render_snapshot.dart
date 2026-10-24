import '../models/category_definition.dart';
import '../models/json.dart';

/// The product as currently drawn (CLAUDE.md 4.2): produced by the builder
/// engine, consumed by the animation engine and the cart. Describes layers
/// by asset id; it never carries prices.
class RenderSnapshot {
  const RenderSnapshot({
    required this.baseAssetId,
    required this.layers,
    this.scale = 1,
    this.cookedBaseAssetId,
  });

  final String baseAssetId;
  final String? cookedBaseAssetId;
  final List<RenderLayer> layers;
  final double scale;

  factory RenderSnapshot.fromJson(Json j) => RenderSnapshot(
    baseAssetId: req(j, 'baseAssetId'),
    cookedBaseAssetId: opt(j, 'cookedBaseAssetId'),
    layers: reqList(j, 'layers', RenderLayer.fromJson),
    scale: toDouble(j['scale'] ?? 1),
  );

  Json toJson() => {
    'baseAssetId': baseAssetId,
    if (cookedBaseAssetId != null) 'cookedBaseAssetId': cookedBaseAssetId,
    'layers': [for (final l in layers) l.toJson()],
    'scale': scale,
  };

  @override
  bool operator ==(Object other) =>
      other is RenderSnapshot &&
      other.baseAssetId == baseAssetId &&
      other.cookedBaseAssetId == cookedBaseAssetId &&
      listEq(other.layers, layers) &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(
    baseAssetId,
    cookedBaseAssetId,
    Object.hashAll(layers),
    scale,
  );
}

class RenderLayer {
  const RenderLayer({
    required this.ingredientId,
    required this.assetId,
    required this.qty,
    required this.layerOrder,
  });

  final String ingredientId;
  final String assetId;
  final int qty;
  final int layerOrder;

  factory RenderLayer.fromJson(Json j) => RenderLayer(
    ingredientId: req(j, 'ingredientId'),
    assetId: req(j, 'assetId'),
    qty: req(j, 'qty'),
    layerOrder: req(j, 'layerOrder'),
  );

  Json toJson() => {
    'ingredientId': ingredientId,
    'assetId': assetId,
    'qty': qty,
    'layerOrder': layerOrder,
  };

  @override
  bool operator ==(Object other) =>
      other is RenderLayer &&
      other.ingredientId == ingredientId &&
      other.assetId == assetId &&
      other.qty == qty &&
      other.layerOrder == layerOrder;

  @override
  int get hashCode => Object.hash(ingredientId, assetId, qty, layerOrder);
}

/// Weighted animation steps taken from a definition (CLAUDE.md 4.2).
class StepSequence {
  const StepSequence(this.steps);

  factory StepSequence.fromDefinition(CategoryDefinition d) =>
      StepSequence(d.animation);

  final List<StepSpec> steps;

  double get totalWeight => steps.fold(0, (s, x) => s + x.weight);

  /// Share of a total duration each step gets, in order.
  List<double> get shares => [
    for (final s in steps) totalWeight == 0 ? 0 : s.weight / totalWeight,
  ];

  factory StepSequence.fromJson(Json j) =>
      StepSequence(reqList(j, 'steps', StepSpec.fromJson));

  Json toJson() => {
    'steps': [for (final s in steps) s.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is StepSequence && listEq(other.steps, steps);

  @override
  int get hashCode => Object.hashAll(steps);
}
