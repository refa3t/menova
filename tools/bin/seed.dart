// P1-A03: seeds a category's catalog from JSON into Firestore.
//
// Validates everything with the `core` models first and refuses to write if
// any referenced asset is missing (fail-closed). Writes as the logged-in
// Firebase CLI user (IAM owner) through the Firestore REST API, so no
// service-account key is needed and security rules stay locked for clients.
//
// Usage (from tools/):
//   dart run bin/seed.dart pizza --products seed/pizza_trial.json
//       [--allow-missing-final-images] [--dry-run]
import 'dart:convert';
import 'dart:io';

import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:menova_tools/firestore_rest.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) _usage();
  final category = args.first;
  final productsPath =
      _flagValue(args, '--products') ?? 'seed/${category}_products.json';
  final allowMissingFinal = args.contains('--allow-missing-final-images');
  final dryRun = args.contains('--dry-run');

  final definition = CategoryDefinition.fromJson(
    _readJson('../definitions/$category.json'),
  );
  final manifest = _readJson(
    '../assets_src/$category/cloudinary_manifest.json',
  );
  final ingredientsFile = _readJson('seed/${category}_ingredients.json');

  // Every category's definition and ingredient records: an ingredient is
  // defined once (in the file of the category that introduced it) and other
  // categories reuse it by id, so prices and images keep one source.
  final allDefinitions = [
    for (final f in Directory('../definitions').listSync().whereType<File>())
      if (f.path.endsWith('.json') && !f.path.endsWith('.temp.json'))
        CategoryDefinition.fromJson(
          jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
        ),
  ];
  final ingredientRecords =
      <String, ({Map<String, dynamic> json, Map<String, dynamic> manifest})>{};
  for (final d in allDefinitions) {
    final file = File('seed/${d.id}_ingredients.json');
    final folder = File('../assets_src/${d.id}/cloudinary_manifest.json');
    if (!file.existsSync() || !folder.existsSync()) continue;
    final m = jsonDecode(folder.readAsStringSync()) as Map<String, dynamic>;
    for (final raw
        in (jsonDecode(file.readAsStringSync())
                as Map<String, dynamic>)['ingredients']
            as List) {
      final json = raw as Map<String, dynamic>;
      ingredientRecords[json['id'] as String] = (json: json, manifest: m);
    }
  }

  /// Categories whose definition uses [assetId] (as a base, an option base,
  /// an animation image or an allowed ingredient's image).
  List<String> usedBy(String assetId, {String? ingredientId}) => [
    for (final d in allDefinitions)
      if (d.base.rawAssetId == assetId ||
          d.base.cookedAssetId == assetId ||
          d.optionGroups.any(
            (g) => g.choices.any(
              (c) =>
                  c.base?.rawAssetId == assetId ||
                  c.base?.cookedAssetId == assetId,
            ),
          ) ||
          d.animation.any((s) => '${s.params['images']}'.contains(assetId)) ||
          (ingredientId != null &&
              d.allowedIngredientIds.contains(ingredientId)))
        d.id,
  ];
  final productsFile = _readJson(productsPath);
  final isTemp =
      ingredientsFile['temp'] == true || productsFile['temp'] == true;

  final errors = <String>[];
  final docs = <String, Map<String, Object?>>{};

  Map<String, Object?> manifestEntry(String file) {
    final e = manifest[file];
    if (e == null) errors.add('asset file not uploaded: $file');
    return (e as Map<String, dynamic>?) ?? const {};
  }

  // Base asset.
  final baseFile = '${definition.base.rawAssetId}.webp';
  final base = manifestEntry(baseFile);
  docs['assets/${definition.base.rawAssetId}'] = Asset(
    id: definition.base.rawAssetId,
    kind: 'base',
    name: definition.base.rawAssetId,
    publicId: '${base['publicId']}',
    secureUrl: '${base['secureUrl']}',
    version: (base['version'] as int?) ?? 0,
    layerOrder: 0,
    allowedCategoryIds: usedBy(definition.base.rawAssetId),
  ).toJson();

  // Bases that replace the category base when an option is chosen.
  for (final g in definition.optionGroups) {
    for (final c in g.choices) {
      final b = c.base;
      if (b == null) continue;
      final e = manifestEntry('${b.rawAssetId}.webp');
      docs['assets/${b.rawAssetId}'] = Asset(
        id: b.rawAssetId,
        kind: 'base',
        name: b.rawAssetId,
        publicId: '${e['publicId']}',
        secureUrl: '${e['secureUrl']}',
        version: (e['version'] as int?) ?? 0,
        layerOrder: 0,
        allowedCategoryIds: usedBy(b.rawAssetId),
      ).toJson();
    }
  }

  // Animation assets (e.g. oven layers). Files named <id>_<NN> are frames
  // of one asset, kept in order as its variants.
  final animFile = File('../assets_src/animation/cloudinary_manifest.json');
  final animManifest = animFile.existsSync()
      ? jsonDecode(animFile.readAsStringSync()) as Map<String, dynamic>
      : <String, dynamic>{};
  final groups = <String, List<String>>{};
  for (final f in animManifest.keys.toList()..sort()) {
    final stem = f.split('.').first;
    final id = stem.replaceFirst(RegExp(r'_\d+$'), '');
    (groups[id] ??= []).add(f);
  }
  for (final g in groups.entries) {
    final users = usedBy(g.key);
    if (users.isEmpty) continue; // Not used by any category.
    final entries = [
      for (final f in g.value) animManifest[f] as Map<String, dynamic>,
    ];
    docs['assets/${g.key}'] = Asset(
      id: g.key,
      kind: 'animation',
      name: g.key,
      publicId: '${entries.first['publicId']}',
      secureUrl: '${entries.first['secureUrl']}',
      version: (entries.first['version'] as int?) ?? 0,
      variants: [for (final e in entries.skip(1)) '${e['secureUrl']}'],
      layerOrder: 0,
      allowedCategoryIds: users,
    ).toJson();
  }

  // Ingredients and their assets: this category's own records, plus the
  // ones it reuses from other categories (same record, same images).
  final ingredientIds = <String>{};
  for (final raw in ingredientsFile['ingredients'] as List) {
    final id = (raw as Map<String, dynamic>)['id'] as String;
    if (!definition.allowedIngredientIds.contains(id)) {
      errors.add('ingredient $id not allowed by definition');
    }
  }
  for (final id in definition.allowedIngredientIds) {
    final record = ingredientRecords[id];
    if (record == null) {
      errors.add('allowed ingredient $id has no ingredient record');
      continue;
    }
    final ingredient = Ingredient.fromJson(record.json);
    ingredientIds.add(id);
    final files = (record.json['assetFiles'] as List).cast<String>();
    if (files.isEmpty) errors.add('ingredient $id has no assets');
    final entries = [
      for (final f in files)
        if (record.manifest[f] case final Map<String, dynamic> e)
          e
        else
          (() {
            errors.add('asset file not uploaded: $f');
            return const <String, dynamic>{};
          })(),
    ];
    if (entries.isEmpty) continue;
    docs['assets/${ingredient.assetId}'] = Asset(
      id: ingredient.assetId,
      kind: 'ingredient',
      name: ingredient.name,
      publicId: '${entries.first['publicId']}',
      secureUrl: '${entries.first['secureUrl']}',
      version: (entries.first['version'] as int?) ?? 0,
      variants: [for (final e in entries.skip(1)) '${e['secureUrl']}'],
      // TEMP: uniform layer order until P1-B00 calibrates layering.
      layerOrder: 20,
      allowedCategoryIds: usedBy(ingredient.assetId, ingredientId: id),
    ).toJson();
    docs['ingredients/${ingredient.id}'] = ingredient.toJson();
  }

  // Products.
  final missingFinal = <String>[];
  for (final raw in productsFile['products'] as List) {
    final product = Product.fromJson(raw as Map<String, dynamic>);
    if (product.categoryId != definition.id) {
      errors.add('${product.id}: categoryId ${product.categoryId}');
    }
    for (final d in product.defaults) {
      if (!ingredientIds.contains(d.ingredientId)) {
        errors.add('${product.id}: unknown default ${d.ingredientId}');
      }
    }
    for (final sizeId in product.sizeDeltas.keys) {
      if (!definition.sizes.any((s) => s.id == sizeId)) {
        errors.add('${product.id}: unknown size $sizeId');
      }
    }
    final group = product.groupId;
    if (group != null && !definition.productGroups.any((g) => g.id == group)) {
      errors.add('${product.id}: unknown group $group');
    }
    if (!manifest.containsKey('${product.imageAssetId}.webp')) {
      missingFinal.add(product.id);
    }
    docs['products/${product.id}'] = product.toJson();
  }
  // P1-A10: the definition itself must be valid against the catalog.
  final assetIds = {
    for (final f in manifest.keys) f.split('.').first,
    ...groups.keys,
  };
  for (final i in validateDefinition(
    definition,
    assetIds: assetIds,
    ingredientIds: ingredientIds,
  )) {
    errors.add('definition: $i');
  }
  if (missingFinal.isNotEmpty && !allowMissingFinal) {
    errors.add(
      'missing final product images for: ${missingFinal.join(', ')} '
      '(pass --allow-missing-final-images for TEMP staging data)',
    );
  }

  docs['categoryContent/${definition.id}'] = CategoryContent(
    categoryId: definition.id,
    isVisible: true,
    displayOrder: (productsFile['categoryOrder'] as int?) ?? 0,
  ).toJson();

  if (errors.isNotEmpty) {
    stderr.writeln('Seed refused, ${errors.length} problem(s):');
    for (final e in errors) {
      stderr.writeln('  - $e');
    }
    exit(1);
  }
  if (isTemp) {
    for (final d in docs.values) {
      d['temp'] = true;
    }
  }

  print(
    '${docs.length} documents validated'
    '${isTemp ? ' (TEMP data, staging only)' : ''}'
    '${missingFinal.isEmpty ? '' : ', ${missingFinal.length} without final image'}',
  );
  if (dryRun) return;

  await batchWrite(stagingProjectId, await firebaseToken(), docs);
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

String? _flagValue(List<String> args, String flag) {
  final i = args.indexOf(flag);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

Never _usage() {
  stderr.writeln(
    'usage: dart run bin/seed.dart <category> '
    '[--products <file>] [--allow-missing-final-images] [--dry-run]',
  );
  exit(64);
}
