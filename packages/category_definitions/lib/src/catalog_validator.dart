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

/// Validates an ingredient record the admin edits (P3-03). [ingredientAssets]
/// are the asset ids of kind `ingredient`; null skips that check.
List<DefinitionIssue> validateIngredient(
  Ingredient i, {
  Set<String>? ingredientAssets,
}) {
  final issues = <DefinitionIssue>[];
  void issue(String path, String message) =>
      issues.add(DefinitionIssue(path, message));
  if (i.id.trim().isEmpty) issue('id', 'must not be empty');
  if (i.name.trim().isEmpty) issue('name', 'must not be empty');
  for (final e in i.names.entries) {
    if (e.value.trim().isEmpty) issue('names.${e.key}', 'must not be empty');
  }
  if (i.extraPrice < 0) issue('extraPrice', 'must be >= 0');
  for (final e in i.sizeMultipliers.entries) {
    if (e.value <= 0) issue('sizeMultipliers.${e.key}', 'must be above zero');
  }
  if (ingredientAssets != null && !ingredientAssets.contains(i.assetId)) {
    issue('assetId', 'unknown ingredient image "${i.assetId}"');
  }
  return issues;
}

/// What the admin panel learned about a picked image before upload (P3-04).
class AssetFile {
  const AssetFile({
    required this.format,
    required this.bytes,
    required this.hasTransparency,
  });

  /// `png`, `webp` or null when the content is neither (read from the file's
  /// first bytes, not its name).
  final String? format;
  final int bytes;
  final bool hasTransparency;

  /// The format from a file's first bytes.
  static String? sniff(List<int> head) {
    bool at(int offset, List<int> sig) {
      if (head.length < offset + sig.length) return false;
      for (var i = 0; i < sig.length; i++) {
        if (head[offset + i] != sig[i]) return false;
      }
      return true;
    }

    if (at(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
      return 'png';
    }
    // RIFF....WEBP
    if (at(0, const [0x52, 0x49, 0x46, 0x46]) &&
        at(8, const [0x57, 0x45, 0x42, 0x50])) {
      return 'webp';
    }
    return null;
  }
}

/// Checks a picked image against its kind's AssetSpec (format, size,
/// transparency), so an image outside the spec is refused before upload and
/// the current one stays.
List<DefinitionIssue> validateAssetFile(AssetFile f, AssetSpec spec) {
  final issues = <DefinitionIssue>[];
  if (f.format == null || !spec.formats.contains(f.format)) {
    issues.add(
      DefinitionIssue('format', 'must be ${spec.formats.join(' or ')}'),
    );
  }
  if (f.bytes > spec.maxBytes) {
    issues.add(DefinitionIssue('bytes', 'must be <= ${spec.maxBytes} bytes'));
  }
  if (spec.transparent && !f.hasTransparency) {
    issues.add(
      const DefinitionIssue('transparent', 'needs a transparent background'),
    );
  }
  return issues;
}

/// One catalog problem found by [checkCatalog].
class CatalogFinding {
  const CatalogFinding({
    required this.kind,
    required this.id,
    required this.issues,
  });

  /// `product` or `ingredient`.
  final String kind;
  final String id;
  final List<DefinitionIssue> issues;
}

/// The whole catalog against the definitions (P3-06): every product within
/// its category's definition, and every ingredient with a known image. A
/// product of a category with no valid definition is a finding too.
List<CatalogFinding> checkCatalog({
  required Map<String, CategoryDefinition> definitions,
  required Iterable<Product> products,
  required Map<String, Ingredient> ingredients,
  required Set<String> ingredientAssets,
}) {
  final findings = <CatalogFinding>[];
  for (final p in products) {
    final def = definitions[p.categoryId];
    final issues = def == null
        ? [DefinitionIssue('categoryId', 'no definition "${p.categoryId}"')]
        : validateProduct(p, def, ingredientIds: ingredients.keys.toSet());
    if (issues.isNotEmpty) {
      findings.add(CatalogFinding(kind: 'product', id: p.id, issues: issues));
    }
  }
  for (final i in ingredients.values) {
    final issues = validateIngredient(i, ingredientAssets: ingredientAssets);
    if (issues.isNotEmpty) {
      findings.add(
        CatalogFinding(kind: 'ingredient', id: i.id, issues: issues),
      );
    }
  }
  return findings;
}
