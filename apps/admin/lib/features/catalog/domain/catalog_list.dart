import 'package:core/core.dart';

/// One audited write: [after] replaces the document at [path] and an audit
/// entry (who, what, when, [before] and [after]) goes in the same batch.
class AuditedChange {
  const AuditedChange({
    required this.action,
    required this.path,
    required this.after,
    this.before,
  });

  final String action;
  final String path;
  final Json after;
  final Json? before;
}

/// Firestore rules may read at most 20 documents per batched write, and
/// each audited write reads its audit entry (the emulator accepts 20 such
/// writes per batch and refuses 21). Ten per batch (20 writes with their
/// entries) leaves room, far below the 500-writes limit.
const maxChangesPerBatch = 10;

/// [items] split into runs of at most [size], in order.
List<List<T>> chunked<T>(List<T> items, [int size = maxChangesPerBatch]) {
  assert(size > 0);
  return [
    for (var i = 0; i < items.length; i += size)
      items.sublist(i, i + size > items.length ? items.length : i + size),
  ];
}

/// The audited saves that set [value] on [products], skipping those already
/// there (the same write the single switch makes).
List<AuditedChange> productAvailabilityChanges(
  Iterable<Product> products,
  bool value,
) => [
  for (final p in products)
    if (p.isAvailable != value)
      AuditedChange(
        action: 'saveProduct',
        path: 'products/${p.id}',
        before: p.toJson(),
        after: Product.fromJson({...p.toJson(), 'isAvailable': value}).toJson(),
      ),
];

/// The audited saves that set [value] on [ingredients], skipping those
/// already there.
List<AuditedChange> ingredientAvailabilityChanges(
  Iterable<Ingredient> ingredients,
  bool value,
) => [
  for (final i in ingredients)
    if (i.isAvailable != value)
      AuditedChange(
        action: 'saveIngredient',
        path: 'ingredients/${i.id}',
        before: i.toJson(),
        after: {...i.toJson(), 'isAvailable': value},
      ),
];

/// Status filter of the products and ingredients lists.
enum StatusFilter { all, available, stopped, drafted }

/// Whether a record passes [status]; [drafted] says it has a pending draft.
bool matchesStatus(
  StatusFilter status, {
  required bool isAvailable,
  required bool drafted,
}) => switch (status) {
  StatusFilter.all => true,
  StatusFilter.available => isAvailable,
  StatusFilter.stopped => !isAvailable,
  StatusFilter.drafted => drafted,
};

/// Whether [query] (already trimmed) is in the Arabic name or, ignoring
/// case, the English one.
bool matchesQuery(String query, String name, Map<String, String> names) =>
    query.isEmpty ||
    (names['ar'] ?? name).contains(query) ||
    name.contains(query) ||
    (names['en'] ?? '').toLowerCase().contains(query.toLowerCase());

/// The products shown for the chosen filters, in their list order.
List<Product> filterProducts(
  List<Product> all, {
  String? categoryId,
  StatusFilter status = StatusFilter.all,
  String query = '',
  Set<String> draftTargets = const {},
}) => [
  for (final p in all)
    if ((categoryId == null || p.categoryId == categoryId) &&
        matchesStatus(
          status,
          isAvailable: p.isAvailable,
          drafted: draftTargets.contains('products/${p.id}'),
        ) &&
        matchesQuery(query, p.name, p.names))
      p,
];

/// The ingredients shown for the chosen filters, by Arabic name. A category
/// filter keeps the ingredients its definition allows.
List<Ingredient> filterIngredients(
  Iterable<Ingredient> all, {
  CategoryDefinition? category,
  StatusFilter status = StatusFilter.all,
  String query = '',
  Set<String> draftTargets = const {},
}) {
  String ar(Ingredient i) => i.names['ar'] ?? i.name;
  return [
    for (final i in all)
      if ((category == null || category.allowedIngredientIds.contains(i.id)) &&
          matchesStatus(
            status,
            isAvailable: i.isAvailable,
            drafted: draftTargets.contains('ingredients/${i.id}'),
          ) &&
          matchesQuery(query, i.name, i.names))
        i,
  ]..sort((a, b) => ar(a).compareTo(ar(b)));
}

/// Each size's full price in the definition's size order (base + delta), or
/// the base price alone when the product has no sizes.
List<Piasters> sizePrices(Product p, CategoryDefinition? def) {
  final sized = [
    for (final s in def?.sizes ?? const <SizeOption>[])
      if (p.sizeDeltas[s.id] case final delta?) p.basePrice + delta,
  ];
  return sized.isEmpty ? [p.basePrice] : sized;
}
