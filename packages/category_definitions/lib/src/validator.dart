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
    if (!(b.surface > 0 && b.surface <= 1)) {
      issue('$path.surface', 'must be in (0, 1]');
    }
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
  for (final e in d.placement.byIngredient.entries) {
    final path = 'placement.byIngredient.${e.key}';
    if (!d.allowedIngredientIds.contains(e.key)) {
      issue(path, 'ingredient not allowed by the category');
    }
    if (placementStrategies != null && !placementStrategies.contains(e.value)) {
      issue(path, 'unregistered "${e.value}"');
    }
  }
  // No param is negative. The area the pieces fill must also have a size:
  // a 0 band lays every piece on one line, and a 0 radius divides by 0.
  for (final e in d.placement.params.entries) {
    final path = 'placement.params.${e.key}';
    if (_areaParams.contains(e.key.split(':').first)) {
      if (!(e.value > 0)) issue(path, 'must be > 0');
    } else if (e.value < 0) {
      issue(path, 'must be >= 0');
    }
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

  void checkNames(String path, String name, Map<String, String> names) {
    if (name.trim().isEmpty) issue('$path.name', 'must not be empty');
    for (final e in names.entries) {
      if (e.value.trim().isEmpty) {
        issue('$path.names.${e.key}', 'must not be empty');
      }
    }
  }

  final productGroupIds = <String>{};
  for (final (i, g) in d.productGroups.indexed) {
    final path = 'productGroups[$i]';
    if (!productGroupIds.add(g.id)) issue('$path.id', 'duplicate "${g.id}"');
    checkNames(path, g.name, g.names);
  }
  final addOnIds = <String>{};
  for (final (i, g) in d.addOnGroups.indexed) {
    final path = 'addOnGroups[$i]';
    if (!addOnIds.add(g.id)) issue('$path.id', 'duplicate "${g.id}"');
    checkNames(path, g.name, g.names);
    if (g.ingredientIds.isEmpty) {
      issue('$path.ingredientIds', 'must not be empty');
    }
    // One ingredient has one quantity, so a product shows it on one tile:
    // once per group, and in no other group offered to the same products.
    final listed = <String>{};
    for (final (k, id) in g.ingredientIds.indexed) {
      if (!allowed.contains(id)) {
        issue('$path.ingredientIds', 'ingredient "$id" is not allowed');
      }
      if (!listed.add(id)) {
        issue('$path.ingredientIds[$k]', 'duplicate "$id"');
        continue;
      }
      for (final (h, earlier) in d.addOnGroups.take(i).indexed) {
        if (_offeredTogether(earlier, g) &&
            earlier.ingredientIds.contains(id)) {
          issue(
            '$path.ingredientIds[$k]',
            '"$id" is also in addOnGroups[$h] ("${earlier.id}"); a product '
                'offered both would show it twice',
          );
          break;
        }
      }
    }
    for (final id in g.productGroupIds) {
      if (!productGroupIds.contains(id)) {
        issue('$path.productGroupIds', 'unknown product group "$id"');
      }
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

/// Placement params sizing the area the pieces fill, as a key or in its
/// per-ingredient form `key:<ingredientId>`.
const _areaParams = {'radius', 'bandWidth'};

/// Whether some product is offered both [a] and [b]. A group without
/// product groups is offered to every product.
bool _offeredTogether(AddOnGroup a, AddOnGroup b) =>
    a.productGroupIds.isEmpty ||
    b.productGroupIds.isEmpty ||
    a.productGroupIds.any(b.productGroupIds.contains);
