import 'package:category_definitions/category_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/order_verification.dart';

final _productsProvider = StreamProvider<Map<String, Product>>(
  (ref) => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map((s) => {for (final d in s.docs) d.id: Product.fromJson(d.data())}),
);

final _ingredientsProvider = StreamProvider<Map<String, Ingredient>>(
  (ref) => FirebaseFirestore.instance
      .collection('ingredients')
      .snapshots()
      .map(
        (s) => {for (final d in s.docs) d.id: Ingredient.fromJson(d.data())},
      ),
);

/// Current products and ingredients (live) plus the bundled definitions,
/// for re-pricing orders on the board. Null until both have loaded.
final pricingDataProvider = Provider<PricingData?>((ref) {
  final products = ref.watch(_productsProvider).value;
  final ingredients = ref.watch(_ingredientsProvider).value;
  if (products == null || ingredients == null) return null;
  return PricingData(
    definitions: loadBundledDefinitions().definitions,
    products: products,
    ingredients: ingredients,
  );
});
