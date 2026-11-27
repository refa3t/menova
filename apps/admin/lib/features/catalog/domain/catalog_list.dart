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

/// [record] (a product or ingredient JSON) switched to [isAvailable], and
/// stopped until [until] (epoch milliseconds) when given. Any earlier
/// «until» is cleared: the writer replaces the whole document.
Json withAvailability(Json record, {required bool isAvailable, int? until}) =>
    {...record, 'isAvailable': isAvailable}
      ..remove('unavailableUntil')
      ..addAll({'unavailableUntil': ?until});

/// The audited save of [before] to [after] under [action], or null when
/// nothing changes.
AuditedChange? _change(String action, String path, Json before, Json after) =>
    before['isAvailable'] == after['isAvailable'] &&
        before['unavailableUntil'] == after['unavailableUntil']
    ? null
    : AuditedChange(action: action, path: path, before: before, after: after);

/// The audited saves that set [value] on [products] (start clears a stop
/// until a time; stop is until switched on again), skipping those already
/// there (the same write the single switch makes).
List<AuditedChange> productAvailabilityChanges(
  Iterable<Product> products,
  bool value,
) => _productChanges(products, isAvailable: value);

/// The audited saves that stop [products] until [until] (epoch
/// milliseconds, «إيقاف لنهاية اليوم»): they stay switched on and come back
/// by themselves then.
List<AuditedChange> productStopUntilChanges(
  Iterable<Product> products,
  int until,
) => _productChanges(products, isAvailable: true, until: until);

List<AuditedChange> _productChanges(
  Iterable<Product> products, {
  required bool isAvailable,
  int? until,
}) => [
  for (final p in products)
    ?_change(
      'saveProduct',
      'products/${p.id}',
      p.toJson(),
      Product.fromJson(
        withAvailability(p.toJson(), isAvailable: isAvailable, until: until),
      ).toJson(),
    ),
];

/// The audited saves that set [value] on [ingredients], skipping those
/// already there.
List<AuditedChange> ingredientAvailabilityChanges(
  Iterable<Ingredient> ingredients,
  bool value,
) => _ingredientChanges(ingredients, isAvailable: value);

/// The audited saves that stop [ingredients] until [until], as
/// [productStopUntilChanges].
List<AuditedChange> ingredientStopUntilChanges(
  Iterable<Ingredient> ingredients,
  int until,
) => _ingredientChanges(ingredients, isAvailable: true, until: until);

List<AuditedChange> _ingredientChanges(
  Iterable<Ingredient> ingredients, {
  required bool isAvailable,
  int? until,
}) => [
  for (final i in ingredients)
    ?_change(
      'saveIngredient',
      'ingredients/${i.id}',
      i.toJson(),
      withAvailability(i.toJson(), isAvailable: isAvailable, until: until),
    ),
];

/// When a record stopped «لنهاية اليوم» at [now] comes back: the next
/// [dayEndHour]:00 in the device's local time (today if still ahead, else
/// tomorrow), as epoch milliseconds.
int dayEndUntil(DateTime now, int dayEndHour) =>
    nextDayEndAt(now.toLocal(), dayEndHour).millisecondsSinceEpoch;

/// The time a record is stopped until at [now], or null when it is not
/// stopped until a time (switched off records are stopped, with no time).
DateTime? pendingUntil({
  required bool isAvailable,
  required int? unavailableUntil,
  required DateTime now,
}) =>
    isAvailable &&
        unavailableUntil != null &&
        !availableAt(
          isAvailable: isAvailable,
          unavailableUntil: unavailableUntil,
          now: now,
        )
    ? DateTime.fromMillisecondsSinceEpoch(unavailableUntil)
    : null;

/// Status filter of the products and ingredients lists.
enum StatusFilter { all, available, stopped, drafted }

/// Whether a record passes [status]; [isAvailable] is its availability now
/// (`isAvailableAt`: a record stopped until a time counts as stopped) and
/// [drafted] says it has a pending draft.
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

/// The products shown for the chosen filters at [now] (default: the current
/// time), in their list order.
List<Product> filterProducts(
  List<Product> all, {
  String? categoryId,
  StatusFilter status = StatusFilter.all,
  String query = '',
  Set<String> draftTargets = const {},
  DateTime? now,
}) => [
  for (final p in all)
    if ((categoryId == null || p.categoryId == categoryId) &&
        matchesStatus(
          status,
          isAvailable: p.isAvailableAt(now ?? DateTime.now()),
          drafted: draftTargets.contains('products/${p.id}'),
        ) &&
        matchesQuery(query, p.name, p.names))
      p,
];

/// The ingredients shown for the chosen filters at [now], by Arabic name. A
/// category filter keeps the ingredients its definition allows.
List<Ingredient> filterIngredients(
  Iterable<Ingredient> all, {
  CategoryDefinition? category,
  StatusFilter status = StatusFilter.all,
  String query = '',
  Set<String> draftTargets = const {},
  DateTime? now,
}) {
  String ar(Ingredient i) => i.names['ar'] ?? i.name;
  final at = now ?? DateTime.now();
  return [
    for (final i in all)
      if ((category == null || category.allowedIngredientIds.contains(i.id)) &&
          matchesStatus(
            status,
            isAvailable: i.isAvailableAt(at),
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
