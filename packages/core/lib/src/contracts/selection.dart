import '../models/catalog.dart';
import '../models/json.dart';

/// What the customer chose (CLAUDE.md 4.2). Produced by the builder engine,
/// consumed by pricing, cart and orders. Added/removed are derived from the
/// difference to the product defaults, never stored.
class Selection {
  const Selection({
    required this.productId,
    required this.categoryId,
    required this.definitionVersion,
    this.sizeId,
    this.options = const {},
    this.ingredients = const {},
    this.notes = '',
  });

  final String productId;
  final String categoryId;
  final int definitionVersion;
  final String? sizeId;

  /// Chosen choice id per option group id.
  final Map<String, String> options;

  /// Selected quantity per ingredient id (defaults included).
  final Map<String, int> ingredients;
  final String notes;

  int qtyOf(String ingredientId) => ingredients[ingredientId] ?? 0;

  /// Quantity above the default, per ingredient (only positive entries).
  Map<String, int> extras(List<ProductIngredient> defaults) {
    final d = {for (final x in defaults) x.ingredientId: x.qty};
    return {
      for (final e in ingredients.entries)
        if (e.value > (d[e.key] ?? 0)) e.key: e.value - (d[e.key] ?? 0),
    };
  }

  /// Default ingredients fully removed by the customer ("بدون X").
  List<String> removed(List<ProductIngredient> defaults) => [
    for (final x in defaults)
      if (qtyOf(x.ingredientId) == 0) x.ingredientId,
  ];

  /// The untouched product: defaults only.
  factory Selection.initial(Product p, {required int definitionVersion}) =>
      Selection(
        productId: p.id,
        categoryId: p.categoryId,
        definitionVersion: definitionVersion,
        ingredients: {for (final d in p.defaults) d.ingredientId: d.qty},
      );

  Selection copyWith({
    String? sizeId,
    Map<String, String>? options,
    Map<String, int>? ingredients,
    String? notes,
  }) => Selection(
    productId: productId,
    categoryId: categoryId,
    definitionVersion: definitionVersion,
    sizeId: sizeId ?? this.sizeId,
    options: options ?? this.options,
    ingredients: ingredients ?? this.ingredients,
    notes: notes ?? this.notes,
  );

  factory Selection.fromJson(Json j) => Selection(
    productId: req(j, 'productId'),
    categoryId: req(j, 'categoryId'),
    definitionVersion: req(j, 'definitionVersion'),
    sizeId: opt(j, 'sizeId'),
    options: mapOf(j, 'options', (v) => v as String),
    ingredients: mapOf(j, 'ingredients', toInt),
    notes: opt(j, 'notes') ?? '',
  );

  Json toJson() => {
    'productId': productId,
    'categoryId': categoryId,
    'definitionVersion': definitionVersion,
    if (sizeId != null) 'sizeId': sizeId,
    'options': options,
    // Zero quantities carry no information; keep the payload canonical.
    'ingredients': _nonZero(ingredients),
    'notes': notes,
  };

  @override
  bool operator ==(Object other) =>
      other is Selection &&
      other.productId == productId &&
      other.categoryId == categoryId &&
      other.definitionVersion == definitionVersion &&
      other.sizeId == sizeId &&
      mapEq(other.options, options) &&
      mapEq(_nonZero(other.ingredients), _nonZero(ingredients)) &&
      other.notes == notes;

  @override
  int get hashCode => Object.hash(
    productId,
    categoryId,
    definitionVersion,
    sizeId,
    mapHash(options),
    mapHash(_nonZero(ingredients)),
    notes,
  );

  /// Zero quantities mean "absent"; equality and JSON ignore them.
  static Map<String, int> _nonZero(Map<String, int> m) => {
    for (final e in m.entries)
      if (e.value > 0) e.key: e.value,
  };
}
