/// Loader and validator for static category definitions bundled from
/// `definitions/`.
library;

import 'dart:convert';

import 'package:core/core.dart';

import 'src/generated/bundled_definitions.g.dart';
import 'src/validator.dart';

export 'src/catalog_validator.dart';
export 'src/validator.dart';

/// Parses and validates every bundled definition. A definition that fails
/// to parse or validate is skipped and reported, so an invalid category never
/// shows (fail-closed). Pass the engines' registry keys from the app.
DefinitionLoadResult loadBundledDefinitions({
  Set<String>? placementStrategies,
  Set<String>? animationSteps,
  Set<String>? enterProfiles,
  Set<String>? exitProfiles,
}) {
  final valid = <String, CategoryDefinition>{};
  final rejected = <String, String>{};
  for (final e in bundledDefinitionSources.entries) {
    try {
      final d = CategoryDefinition.fromJson(
        jsonDecode(e.value) as Map<String, dynamic>,
      );
      final issues = validateDefinition(
        d,
        placementStrategies: placementStrategies,
        animationSteps: animationSteps,
        enterProfiles: enterProfiles,
        exitProfiles: exitProfiles,
      );
      if (issues.isEmpty) {
        valid[d.id] = d;
      } else {
        rejected[e.key] = issues.join('; ');
      }
    } on Object catch (err) {
      rejected[e.key] = '$err';
    }
  }
  return DefinitionLoadResult(valid, rejected);
}

class DefinitionLoadResult {
  const DefinitionLoadResult(this.definitions, this.rejected);

  /// Valid definitions by category id.
  final Map<String, CategoryDefinition> definitions;

  /// File name -> reason, for definitions that were refused.
  final Map<String, String> rejected;
}
