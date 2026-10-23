import 'json.dart';

/// Static, developer-owned category definition (DATA-02). Lives in
/// `definitions/` in the repo, never in Firestore.
class CategoryDefinition {
  const CategoryDefinition({
    required this.id,
    required this.definitionVersion,
    required this.name,
    required this.base,
    required this.allowedIngredientIds,
    required this.placement,
    required this.constraints,
    required this.sizes,
    required this.optionGroups,
    required this.animation,
    required this.assetSpecs,
    this.layerOverrides = const {},
  });

  final String id;
  final int definitionVersion;
  final String name;
  final BaseSpec base;
  final List<String> allowedIngredientIds;
  final PlacementSpec placement;
  final CustomizationConstraints constraints;

  /// Supported sizes. Empty means the category has no size selector.
  final List<SizeOption> sizes;
  final List<OptionGroup> optionGroups;
  final List<StepSpec> animation;

  /// Asset spec per asset kind (e.g. `base`, `ingredient`).
  final Map<String, AssetSpec> assetSpecs;

  /// Per-ingredient layer order overriding the asset default (definition wins).
  final Map<String, int> layerOverrides;

  factory CategoryDefinition.fromJson(Json j) => CategoryDefinition(
    id: req(j, 'id'),
    definitionVersion: req(j, 'definitionVersion'),
    name: req(j, 'name'),
    base: BaseSpec.fromJson(req(j, 'base')),
    allowedIngredientIds: strList(j, 'allowedIngredientIds'),
    placement: PlacementSpec.fromJson(req(j, 'placement')),
    constraints: CustomizationConstraints.fromJson(req(j, 'constraints')),
    sizes: reqList(j, 'sizes', SizeOption.fromJson),
    optionGroups: reqList(j, 'optionGroups', OptionGroup.fromJson),
    animation: reqList(j, 'animation', StepSpec.fromJson),
    assetSpecs: mapOf(j, 'assetSpecs', (v) => AssetSpec.fromJson(v as Json)),
    layerOverrides: mapOf(j, 'layerOverrides', toInt),
  );

  Json toJson() => {
    'id': id,
    'definitionVersion': definitionVersion,
    'name': name,
    'base': base.toJson(),
    'allowedIngredientIds': allowedIngredientIds,
    'placement': placement.toJson(),
    'constraints': constraints.toJson(),
    'sizes': [for (final s in sizes) s.toJson()],
    'optionGroups': [for (final g in optionGroups) g.toJson()],
    'animation': [for (final s in animation) s.toJson()],
    'assetSpecs': {for (final e in assetSpecs.entries) e.key: e.value.toJson()},
    'layerOverrides': layerOverrides,
  };

  @override
  bool operator ==(Object other) =>
      other is CategoryDefinition &&
      other.id == id &&
      other.definitionVersion == definitionVersion &&
      other.name == name &&
      other.base == base &&
      listEq(other.allowedIngredientIds, allowedIngredientIds) &&
      other.placement == placement &&
      other.constraints == constraints &&
      listEq(other.sizes, sizes) &&
      listEq(other.optionGroups, optionGroups) &&
      listEq(other.animation, animation) &&
      mapEq(other.assetSpecs, assetSpecs) &&
      mapEq(other.layerOverrides, layerOverrides);

  @override
  int get hashCode => Object.hash(
    id,
    definitionVersion,
    name,
    base,
    Object.hashAll(allowedIngredientIds),
    placement,
    constraints,
    Object.hashAll(sizes),
    Object.hashAll(optionGroups),
    Object.hashAll(animation),
    mapHash(assetSpecs),
    mapHash(layerOverrides),
  );
}

/// Shape and base assets of the product canvas.
class BaseSpec {
  const BaseSpec({
    required this.shape,
    required this.rawAssetId,
    this.cookedAssetId,
  });

  /// Registered shape key (e.g. `circle`), resolved by the builder engine.
  final String shape;
  final String rawAssetId;
  final String? cookedAssetId;

  factory BaseSpec.fromJson(Json j) => BaseSpec(
    shape: req(j, 'shape'),
    rawAssetId: req(j, 'rawAssetId'),
    cookedAssetId: opt(j, 'cookedAssetId'),
  );

  Json toJson() => {
    'shape': shape,
    'rawAssetId': rawAssetId,
    if (cookedAssetId != null) 'cookedAssetId': cookedAssetId,
  };

  @override
  bool operator ==(Object other) =>
      other is BaseSpec &&
      other.shape == shape &&
      other.rawAssetId == rawAssetId &&
      other.cookedAssetId == cookedAssetId;

  @override
  int get hashCode => Object.hash(shape, rawAssetId, cookedAssetId);
}

/// Registered placement strategy key plus its parameters (e.g. `scatter`).
class PlacementSpec {
  const PlacementSpec({required this.strategy, this.params = const {}});

  final String strategy;
  final Map<String, num> params;

  factory PlacementSpec.fromJson(Json j) => PlacementSpec(
    strategy: req(j, 'strategy'),
    params: mapOf(j, 'params', (v) => v as num),
  );

  Json toJson() => {'strategy': strategy, 'params': params};

  @override
  bool operator ==(Object other) =>
      other is PlacementSpec &&
      other.strategy == strategy &&
      mapEq(other.params, params);

  @override
  int get hashCode => Object.hash(strategy, mapHash(params));
}

class CustomizationConstraints {
  const CustomizationConstraints({required this.maxQty});

  /// Upper bound on an ingredient's quantity. Exact semantics (total vs.
  /// extra above default) pending owner decision (OWNER_INPUTS #8).
  final int maxQty;

  factory CustomizationConstraints.fromJson(Json j) =>
      CustomizationConstraints(maxQty: req(j, 'maxQty'));

  Json toJson() => {'maxQty': maxQty};

  @override
  bool operator ==(Object other) =>
      other is CustomizationConstraints && other.maxQty == maxQty;

  @override
  int get hashCode => maxQty.hashCode;
}

/// A size the category supports. Price deltas live on the product.
class SizeOption {
  const SizeOption({required this.id, required this.name, this.scale = 1});

  final String id;
  final String name;

  /// Visual scale of the canvas for this size.
  final double scale;

  factory SizeOption.fromJson(Json j) => SizeOption(
    id: req(j, 'id'),
    name: req(j, 'name'),
    scale: toDouble(j['scale'] ?? 1),
  );

  Json toJson() => {'id': id, 'name': name, 'scale': scale};

  @override
  bool operator ==(Object other) =>
      other is SizeOption &&
      other.id == id &&
      other.name == name &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(id, name, scale);
}

/// Generic option group (dough is just one instance). Price deltas live on
/// the product, keyed by choice id.
class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.choices,
    required this.defaultChoiceId,
  });

  final String id;
  final String name;
  final List<OptionChoice> choices;
  final String defaultChoiceId;

  factory OptionGroup.fromJson(Json j) => OptionGroup(
    id: req(j, 'id'),
    name: req(j, 'name'),
    choices: reqList(j, 'choices', OptionChoice.fromJson),
    defaultChoiceId: req(j, 'defaultChoiceId'),
  );

  Json toJson() => {
    'id': id,
    'name': name,
    'choices': [for (final c in choices) c.toJson()],
    'defaultChoiceId': defaultChoiceId,
  };

  @override
  bool operator ==(Object other) =>
      other is OptionGroup &&
      other.id == id &&
      other.name == name &&
      listEq(other.choices, choices) &&
      other.defaultChoiceId == defaultChoiceId;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(choices), defaultChoiceId);
}

class OptionChoice {
  const OptionChoice({required this.id, required this.name, this.base});

  final String id;
  final String name;

  /// Replaces the category base when chosen (e.g. a different dough).
  final BaseSpec? base;

  factory OptionChoice.fromJson(Json j) => OptionChoice(
    id: req(j, 'id'),
    name: req(j, 'name'),
    base: j['base'] == null ? null : BaseSpec.fromJson(j['base'] as Json),
  );

  Json toJson() => {
    'id': id,
    'name': name,
    if (base != null) 'base': base!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is OptionChoice &&
      other.id == id &&
      other.name == name &&
      other.base == base;

  @override
  int get hashCode => Object.hash(id, name, base);
}

/// One animation step: a registered step key with weight and parameters.
/// Formalized as `StepSequence` in P1-A08.
class StepSpec {
  const StepSpec({required this.step, this.weight = 1, this.params = const {}});

  final String step;
  final double weight;
  final Map<String, Object?> params;

  factory StepSpec.fromJson(Json j) => StepSpec(
    step: req(j, 'step'),
    weight: toDouble(j['weight'] ?? 1),
    params: mapOf(j, 'params', (v) => v),
  );

  Json toJson() => {'step': step, 'weight': weight, 'params': params};

  @override
  bool operator ==(Object other) =>
      other is StepSpec &&
      other.step == step &&
      other.weight == weight &&
      mapEq(other.params, params);

  @override
  int get hashCode => Object.hash(step, weight, mapHash(params));
}

/// Technical constraints an asset of a given kind must satisfy.
class AssetSpec {
  const AssetSpec({
    required this.formats,
    required this.maxBytes,
    required this.transparent,
  });

  final List<String> formats;
  final int maxBytes;
  final bool transparent;

  factory AssetSpec.fromJson(Json j) => AssetSpec(
    formats: strList(j, 'formats'),
    maxBytes: req(j, 'maxBytes'),
    transparent: req(j, 'transparent'),
  );

  Json toJson() => {
    'formats': formats,
    'maxBytes': maxBytes,
    'transparent': transparent,
  };

  @override
  bool operator ==(Object other) =>
      other is AssetSpec &&
      listEq(other.formats, formats) &&
      other.maxBytes == maxBytes &&
      other.transparent == transparent;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(formats), maxBytes, transparent);
}
