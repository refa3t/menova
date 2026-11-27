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

/// The raw menu collections as loaded, before availability is decided: a
/// [Menu] is this source seen at one moment ([at]), so the shown menu can
/// follow the clock (a product stopped until the end of the day comes back
/// by itself) without loading again.
class MenuSource {
  const MenuSource({
    required this.definitions,
    required this.contents,
    required this.products,
    required this.ingredients,
    required this.assets,
  });

  final Map<String, CategoryDefinition> definitions;
  final List<CategoryContent> contents;
  final List<Product> products;
  final List<Ingredient> ingredients;
  final List<Asset> assets;

  /// The menu as it stands at [now].
  Menu at(DateTime now) => Menu.assemble(
    definitions: definitions,
    contents: contents,
    products: products,
    ingredients: ingredients,
    assets: assets,
    now: now,
  );
}

class Menu {
  const Menu({
    required this.categories,
    required this.ingredients,
    required this.assets,
    required this.at,
    this.nextAvailabilityChange,
  });

  /// Visible categories ordered by `displayOrder`.
  final List<MenuCategory> categories;

  /// Every ingredient record (available or not) by id.
  final Map<String, Ingredient> ingredients;
  final Map<String, Asset> assets;

  /// The moment availability was decided for.
  final DateTime at;

  /// When the next product or ingredient stopped until a time comes back,
  /// or null if none is pending: the menu must be seen again then.
  final DateTime? nextAvailabilityChange;

  /// Whether the ingredient exists and is available at [at].
  bool ingredientAvailable(String id) =>
      ingredients[id]?.isAvailableAt(at) ?? false;

  /// The product's final image, or its category base until one exists.
  String? cardImageUrl(Product product, CategoryDefinition definition) =>
      assets[product.imageAssetId]?.secureUrl ??
      assets[definition.base.rawAssetId]?.secureUrl;

  /// Assembles the menu from raw collections at [now] (default: the
  /// current time). Categories without a valid bundled definition never
  /// show (fail-closed), nor do products unavailable at [now].
  factory Menu.assemble({
    required Map<String, CategoryDefinition> definitions,
    required List<CategoryContent> contents,
    required List<Product> products,
    required List<Ingredient> ingredients,
    required List<Asset> assets,
    DateTime? now,
  }) {
    final at = now ?? DateTime.now();
    final visible =
        contents
            .where((c) => c.isVisible && definitions.containsKey(c.categoryId))
            .toList()
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
    final next = earliestPendingUntil([
      for (final p in products)
        if (p.isAvailable) p.unavailableUntil,
      for (final i in ingredients)
        if (i.isAvailable) i.unavailableUntil,
    ], at);
    return Menu(
      categories: [
        for (final c in visible)
          MenuCategory(
            definition: definitions[c.categoryId]!,
            content: c,
            products:
                products
                    .where(
                      (p) =>
                          p.categoryId == c.categoryId && p.isAvailableAt(at),
                    )
                    .toList()
                  ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder)),
          ),
      ],
      ingredients: {for (final i in ingredients) i.id: i},
      assets: {for (final a in assets) a.id: a},
      at: at,
      nextAvailabilityChange: next == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(next),
    );
  }
}
