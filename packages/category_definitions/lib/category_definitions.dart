/// Loader for static category definitions bundled from `definitions/`.
library;

import 'dart:convert';

import 'package:core/core.dart';

import 'src/generated/bundled_definitions.g.dart';

/// Parses every bundled definition. A definition that fails to parse is
/// skipped and reported, so an invalid category never shows (fail-closed).
/// Full semantic validation is added in P1-A10.
DefinitionLoadResult loadBundledDefinitions() {
  final valid = <String, CategoryDefinition>{};
  final rejected = <String, String>{};
  for (final e in bundledDefinitionSources.entries) {
    try {
      final d = CategoryDefinition.fromJson(
        jsonDecode(e.value) as Map<String, dynamic>,
      );
      valid[d.id] = d;
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
