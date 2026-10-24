import 'package:core/core.dart';

/// One reason a definition is invalid (FR-CD-04).
class DefinitionIssue {
  const DefinitionIssue(this.path, this.message);

  final String path;
  final String message;

  @override
  String toString() => '$path: $message';
}

/// Validates a category definition. Registries and catalogs are passed in by
/// the caller, so this package never depends on the engines (ARC-03). A null
/// argument skips the checks that need it.
List<DefinitionIssue> validateDefinition(
  CategoryDefinition d, {
  Set<String>? placementStrategies,
  Set<String>? animationSteps,
  Set<String>? enterProfiles,
  Set<String>? exitProfiles,
  Set<String>? assetIds,
  Set<String>? ingredientIds,
}) {
  final issues = <DefinitionIssue>[];
  void issue(String path, String message) =>
      issues.add(DefinitionIssue(path, message));

  if (d.id.isEmpty) issue('id', 'must not be empty');
  if (d.definitionVersion < 1) issue('definitionVersion', 'must be >= 1');

  // Assets.
  void checkBase(String path, BaseSpec b) {
    if (assetIds == null) return;
    if (!assetIds.contains(b.rawAssetId)) {
      issue('$path.rawAssetId', 'unknown asset "${b.rawAssetId}"');
    }
    final cooked = b.cookedAssetId;
    if (cooked != null && !assetIds.contains(cooked)) {
      issue('$path.cookedAssetId', 'unknown asset "$cooked"');
    }
  }

  checkBase('base', d.base);

  // Registered extension points.
  if (placementStrategies != null &&
      !placementStrategies.contains(d.placement.strategy)) {
    issue('placement.strategy', 'unregistered "${d.placement.strategy}"');
  }
  for (final e in d.placement.params.entries) {
    if (e.value < 0) issue('placement.params.${e.key}', 'must be >= 0');
  }
  if (d.animation.isEmpty) issue('animation', 'must have at least one step');
  for (final (i, s) in d.animation.indexed) {
    if (animationSteps != null && !animationSteps.contains(s.step)) {
      issue('animation[$i].step', 'unregistered "${s.step}"');
    }
    if (s.weight <= 0) issue('animation[$i].weight', 'must be > 0');
    final images = s.params['images'];
    if (assetIds != null && images is Map) {
      for (final e in images.entries) {
        if (!assetIds.contains(e.value)) {
          issue(
            'animation[$i].params.images.${e.key}',
            'unknown asset "${e.value}"',
          );
        }
      }
    }
  }

  // Ingredients.
  final allowed = d.allowedIngredientIds.toSet();
  if (allowed.length != d.allowedIngredientIds.length) {
    issue('allowedIngredientIds', 'contains duplicates');
  }
  if (ingredientIds != null) {
    for (final id in allowed.difference(ingredientIds)) {
      issue('allowedIngredientIds', 'ingredient "$id" is not defined');
    }
  }
  for (final id in d.layerOverrides.keys) {
    if (!allowed.contains(id)) {
      issue('layerOverrides.$id', 'ingredient is not allowed');
    }
  }

  for (final e in d.ingredientMotion.entries) {
    final path = 'ingredientMotion.${e.key}';
    if (!allowed.contains(e.key)) issue(path, 'ingredient is not allowed');
    if (enterProfiles != null && !enterProfiles.contains(e.value.enter)) {
      issue('$path.enter', 'unregistered "${e.value.enter}"');
    }
    if (exitProfiles != null && !exitProfiles.contains(e.value.exit)) {
      issue('$path.exit', 'unregistered "${e.value.exit}"');
    }
  }

  // Limits.
  if (d.constraints.maxQty < 1) issue('constraints.maxQty', 'must be >= 1');
  final sizeIds = <String>{};
  for (final (i, s) in d.sizes.indexed) {
    if (!sizeIds.add(s.id)) issue('sizes[$i].id', 'duplicate "${s.id}"');
    if (s.scale <= 0) issue('sizes[$i].scale', 'must be > 0');
  }
  final groupIds = <String>{};
  for (final (i, g) in d.optionGroups.indexed) {
    final path = 'optionGroups[$i]';
    if (!groupIds.add(g.id)) issue('$path.id', 'duplicate "${g.id}"');
    if (g.choices.isEmpty) issue('$path.choices', 'must not be empty');
    final choiceIds = <String>{};
    for (final (j, c) in g.choices.indexed) {
      if (!choiceIds.add(c.id)) {
        issue('$path.choices[$j].id', 'duplicate "${c.id}"');
      }
      if (c.base case final b?) checkBase('$path.choices[$j].base', b);
    }
    if (!choiceIds.contains(g.defaultChoiceId)) {
      issue('$path.defaultChoiceId', 'not one of the choices');
    }
  }
  for (final e in d.assetSpecs.entries) {
    if (e.value.maxBytes <= 0) {
      issue('assetSpecs.${e.key}.maxBytes', 'must be > 0');
    }
    if (e.value.formats.isEmpty) {
      issue('assetSpecs.${e.key}.formats', 'must not be empty');
    }
  }
  return issues;
}
