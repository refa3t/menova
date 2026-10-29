import 'package:category_definitions/category_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The developer's category definitions (bundled, read-only for the admin).
final definitionsProvider = Provider<Map<String, CategoryDefinition>>(
  (ref) => loadBundledDefinitions().definitions,
);

/// Every product, live (the admin also sees unavailable ones).
final productsProvider = StreamProvider<List<Product>>(
  (ref) => FirebaseFirestore.instance
      .collection('products')
      .snapshots()
      .map(
        (s) => [for (final d in s.docs) Product.fromJson(d.data())]
          ..sort(
            (a, b) => a.categoryId == b.categoryId
                ? a.displayOrder.compareTo(b.displayOrder)
                : a.categoryId.compareTo(b.categoryId),
          ),
      ),
);

/// Every ingredient record by id, live.
final ingredientsProvider = StreamProvider<Map<String, Ingredient>>(
  (ref) => FirebaseFirestore.instance
      .collection('ingredients')
      .snapshots()
      .map(
        (s) => {for (final d in s.docs) d.id: Ingredient.fromJson(d.data())},
      ),
);
