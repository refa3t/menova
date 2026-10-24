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

  Future<Menu> load() async {
    final results = await Future.wait([
      _db.collection('categoryContent').get(),
      _db.collection('products').get(),
      _db.collection('ingredients').get(),
      _db.collection('assets').get(),
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
