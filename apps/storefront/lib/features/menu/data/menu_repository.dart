import 'package:animation/animation.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:product_builder/product_builder.dart';

import '../domain/menu.dart';

/// Reads the public menu from Firestore. Firestore's local persistence serves
/// the last menu from cache when the connection is weak or offline.
class MenuRepository {
  MenuRepository(this._db);

  final FirebaseFirestore _db;

  /// Loads the menu. [fromServer] skips the cache (used to re-price the
  /// cart right before an order is sent).
  Future<Menu> load({bool fromServer = false}) async {
    final options = GetOptions(
      source: fromServer ? Source.server : Source.serverAndCache,
    );
    final results = await Future.wait([
      _db.collection('categoryContent').get(options),
      _db.collection('products').get(options),
      _db.collection('ingredients').get(options),
      _db.collection('assets').get(options),
    ]);
    List<T> parse<T>(
      QuerySnapshot<Map<String, dynamic>> s,
      T Function(Map<String, dynamic>) f,
    ) => [for (final d in s.docs) f(d.data())];

    return Menu.assemble(
      definitions: loadBundledDefinitions(
        placementStrategies: placementStrategies.keys.toSet(),
        animationSteps: animationStepKeys,
        enterProfiles: enterProfiles.keys.toSet(),
        exitProfiles: exitProfiles.keys.toSet(),
      ).definitions,
      contents: parse(results[0], CategoryContent.fromJson),
      products: parse(results[1], Product.fromJson),
      ingredients: parse(results[2], Ingredient.fromJson),
      assets: parse(results[3], Asset.fromJson),
    );
  }
}
