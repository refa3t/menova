import 'package:core/core.dart';

/// A visible category: its static definition plus admin content and products.
class MenuCategory {
  const MenuCategory({
    required this.definition,
    required this.content,
    required this.products,
  });

  final CategoryDefinition definition;
  final CategoryContent content;

  /// Available products, ordered by `displayOrder`.
  final List<Product> products;
}

class Menu {
  const Menu({
    required this.categories,
    required this.ingredients,
    required this.assets,
  });

  /// Visible categories ordered by `displayOrder`.
  final List<MenuCategory> categories;
  final Map<String, Ingredient> ingredients;
  final Map<String, Asset> assets;

  /// The product's final image, or its category base until one exists.
  String? cardImageUrl(Product product, CategoryDefinition definition) =>
      assets[product.imageAssetId]?.secureUrl ??
      assets[definition.base.rawAssetId]?.secureUrl;

  /// Assembles the menu from raw collections. Categories without a valid
  /// bundled definition never show (fail-closed).
  factory Menu.assemble({
    required Map<String, CategoryDefinition> definitions,
    required List<CategoryContent> contents,
    required List<Product> products,
    required List<Ingredient> ingredients,
    required List<Asset> assets,
  }) {
    final visible = contents
        .where((c) => c.isVisible && definitions.containsKey(c.categoryId))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    return Menu(
      categories: [
        for (final c in visible)
          MenuCategory(
            definition: definitions[c.categoryId]!,
            content: c,
            products: products
                .where((p) => p.categoryId == c.categoryId && p.isAvailable)
                .toList()
              ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
          ),
      ],
      ingredients: {for (final i in ingredients) i.id: i},
      assets: {for (final a in assets) a.id: a},
    );
  }
}
