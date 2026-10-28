import 'dart:convert';
import 'dart:io';

import 'package:animation/animation.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

/// P1-A10 in CI: the real definitions validate against the real engine
/// registries, uploaded assets and seed ingredients.
void main() {
  Map<String, dynamic> read(String p) =>
      jsonDecode(File('../../$p').readAsStringSync()) as Map<String, dynamic>;
  final ids = [
    for (final f in Directory('../../definitions').listSync().whereType<File>())
      if (f.path.endsWith('.json') && !f.path.endsWith('.temp.json'))
        f.uri.pathSegments.last.replaceAll('.json', ''),
  ]..sort();

  // Every category's assets and ingredient records; ingredients are shared
  // across categories by id.
  final assetIds = <String>{
    for (final f in read('assets_src/animation/cloudinary_manifest.json').keys)
      f.split('.').first.replaceFirst(RegExp(r'_\d+$'), ''),
    for (final id in ids)
      if (File('../../assets_src/$id/cloudinary_manifest.json').existsSync())
        for (final f in read('assets_src/$id/cloudinary_manifest.json').keys)
          f.split('.').first,
  };
  final ingredientIds = <String>{
    for (final id in ids)
      if (File('../../tools/seed/${id}_ingredients.json').existsSync())
        for (final i
            in read('tools/seed/${id}_ingredients.json')['ingredients'] as List)
          i['id'] as String,
  };

  for (final id in ids) {
    test('definitions/$id.json is valid', () {
      final def = CategoryDefinition.fromJson(read('definitions/$id.json'));
      final issues = validateDefinition(
        def,
        placementStrategies: placementStrategies.keys.toSet(),
        animationSteps: animationStepKeys,
        enterProfiles: enterProfiles.keys.toSet(),
        exitProfiles: exitProfiles.keys.toSet(),
        assetIds: assetIds,
        ingredientIds: ingredientIds,
      );
      expect(issues, isEmpty);
    });
  }

  test('every bundled definition loads', () {
    final loaded = loadBundledDefinitions(
      placementStrategies: placementStrategies.keys.toSet(),
      animationSteps: animationStepKeys,
      enterProfiles: enterProfiles.keys.toSet(),
      exitProfiles: exitProfiles.keys.toSet(),
    );
    expect(loaded.rejected, isEmpty);
    expect(loaded.definitions.keys.toSet(), ids.toSet());
  });
}
