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
import 'package:http/http.dart' as http;

/// Only the staging project may receive TEMP data (no production project
/// exists yet; OWNER_INPUTS decision 10).
const stagingProjectId = 'menova-80602';

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
    allowedCategoryIds: [definition.id],
  ).toJson();

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
      allowedCategoryIds: [definition.id],
    ).toJson();
  }

  // Ingredients and their assets.
  final ingredientIds = <String>{};
  for (final raw in ingredientsFile['ingredients'] as List) {
    final json = raw as Map<String, dynamic>;
    final ingredient = Ingredient.fromJson(json);
    ingredientIds.add(ingredient.id);
    if (!definition.allowedIngredientIds.contains(ingredient.id)) {
      errors.add('ingredient ${ingredient.id} not allowed by definition');
    }
    final files = (json['assetFiles'] as List).cast<String>();
    if (files.isEmpty) errors.add('ingredient ${ingredient.id} has no assets');
    final entries = files.map(manifestEntry).toList();
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
      allowedCategoryIds: [definition.id],
    ).toJson();
    docs['ingredients/${ingredient.id}'] = ingredient.toJson();
  }
  for (final id in definition.allowedIngredientIds) {
    if (!ingredientIds.contains(id)) {
      errors.add('allowed ingredient $id has no ingredient record');
    }
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
    displayOrder: 0,
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

  final token = (await Process.run('node', ['firebase_token.js']));
  if (token.exitCode != 0) {
    stderr.writeln('Could not get token: ${token.stderr}');
    exit(1);
  }
  await _batchWrite(stagingProjectId, '${token.stdout}'.trim(), docs);
}

Future<void> _batchWrite(
  String projectId,
  String token,
  Map<String, Map<String, Object?>> docs,
) async {
  final root = 'projects/$projectId/databases/(default)/documents';
  final entries = docs.entries.toList();
  // batchWrite accepts up to 500 writes per call.
  for (var i = 0; i < entries.length; i += 500) {
    final chunk = entries.skip(i).take(500);
    final res = await http.post(
      Uri.parse('https://firestore.googleapis.com/v1/$root:batchWrite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'writes': [
          for (final e in chunk)
            {
              'update': {
                'name': '$root/${e.key}',
                'fields': {
                  for (final f in e.value.entries) f.key: _value(f.value),
                },
              },
            },
        ],
      }),
    );
    if (res.statusCode != 200) {
      stderr.writeln('Firestore error ${res.statusCode}: ${res.body}');
      exit(1);
    }
    final statuses = (jsonDecode(res.body)['status'] as List?) ?? const [];
    final failed = statuses.where((s) => (s as Map)['code'] != null).length;
    if (failed > 0) {
      stderr.writeln('$failed writes failed: ${res.body}');
      exit(1);
    }
  }
  print('${docs.length} documents written to $projectId');
}

/// Encodes a JSON value as a Firestore REST `Value`.
Map<String, Object?> _value(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int n => {'integerValue': '$n'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  List l => {
    'arrayValue': {'values': l.map(_value).toList()},
  },
  Map m => {
    'mapValue': {
      'fields': {for (final e in m.entries) '${e.key}': _value(e.value)},
    },
  },
  _ => throw ArgumentError('Unsupported value: $v'),
};

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
