import 'package:core/core.dart';

import 'validator.dart';

/// Validates a product against its category definition (P3-02, and the
/// catalog check of P3-06): the admin may edit content only within what the
/// developer's definition allows. [ingredientIds] are the ingredient
/// records that exist; null skips that check.
List<DefinitionIssue> validateProduct(
  Product p,
  CategoryDefinition def, {
  Set<String>? ingredientIds,
}) {
  final issues = <DefinitionIssue>[];
  void issue(String path, String message) =>
      issues.add(DefinitionIssue(path, message));

  if (p.id.trim().isEmpty) issue('id', 'must not be empty');
  if (p.categoryId != def.id) {
    issue('categoryId', 'is "${p.categoryId}", definition is "${def.id}"');
  }
  if (p.name.trim().isEmpty) issue('name', 'must not be empty');
  for (final e in p.names.entries) {
    if (e.value.trim().isEmpty) issue('names.${e.key}', 'must not be empty');
  }
  if (p.basePrice <= 0) issue('basePrice', 'must be above zero');

  // Size and option prices: only what the definition offers.
  final sizes = {for (final s in def.sizes) s.id};
  for (final e in p.sizeDeltas.entries) {
    if (!sizes.contains(e.key)) issue('sizeDeltas.${e.key}', 'unknown size');
    if (e.value < 0) issue('sizeDeltas.${e.key}', 'must be >= 0');
  }
  final choices = {
    for (final g in def.optionGroups)
      for (final c in g.choices) c.id,
  };
  for (final e in p.optionDeltas.entries) {
    if (!choices.contains(e.key)) {
      issue('optionDeltas.${e.key}', 'unknown option');
    }
    if (e.value < 0) issue('optionDeltas.${e.key}', 'must be >= 0');
  }

  // Default ingredients: allowed by the category, defined, once each.
  final seen = <String>{};
  for (final (i, d) in p.defaults.indexed) {
    final path = 'defaults[$i]';
    if (!seen.add(d.ingredientId)) {
      issue(path, '"${d.ingredientId}" listed twice');
    }
    if (!def.allowedIngredientIds.contains(d.ingredientId)) {
      issue(path, '"${d.ingredientId}" is not allowed in ${def.id}');
    }
    if (ingredientIds != null && !ingredientIds.contains(d.ingredientId)) {
      issue(path, '"${d.ingredientId}" has no ingredient record');
    }
    if (d.qty < 1) issue('$path.qty', 'must be >= 1');
    if (d.refundAmount < 0) issue('$path.refundAmount', 'must be >= 0');
  }

  final group = p.groupId;
  if (group != null &&
      def.productGroups.isNotEmpty &&
      !def.productGroups.any((g) => g.id == group)) {
    issue('groupId', 'unknown group "$group"');
  }
  if (p.displayOrder < 0) issue('displayOrder', 'must be >= 0');
  return issues;
}
