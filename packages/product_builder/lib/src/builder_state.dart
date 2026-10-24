import 'package:core/core.dart';

/// Why a builder change was refused (CLAUDE.md 4.3).
enum BuilderRejection {
  /// The ingredient is not allowed by the category definition.
  notAllowed,

  /// The ingredient is currently unavailable.
  unavailable,

  /// Going above the quantity limit.
  maxQty,

  /// Removing a default that is not removable.
  notRemovable,

  /// Unknown size or option choice for this category.
  unknownChoice,
}

/// Result of a change: the new state, or the reason it was refused.
class BuilderResult {
  const BuilderResult.ok(this.state) : rejection = null;
  const BuilderResult.rejected(this.state, BuilderRejection this.rejection);

  final BuilderState state;
  final BuilderRejection? rejection;

  bool get accepted => rejection == null;
}

/// The builder engine's state: product, size, options and quantities, with
/// the customization rules. Pure logic: no prices, animation or cart
/// (ARC-06), and no category-specific branches (ARC-01).
class BuilderState {
  BuilderState._(
    this.definition,
    this.product,
    this.selection,
    this._unavailable,
  );

  /// Opens a product with its defaults, the default choice of every option
  /// group and the first supported size.
  factory BuilderState.open({
    required CategoryDefinition definition,
    required Product product,
    Set<String> unavailableIngredientIds = const {},
  }) {
    final initial =
        Selection.initial(
          product,
          definitionVersion: definition.definitionVersion,
        ).copyWith(
          sizeId: definition.sizes.isEmpty ? null : definition.sizes.first.id,
          options: {
            for (final g in definition.optionGroups) g.id: g.defaultChoiceId,
          },
        );
    return BuilderState._(
      definition,
      product,
      initial,
      unavailableIngredientIds,
    );
  }

  /// Restores a saved selection (e.g. editing a cart line, AC-18).
  factory BuilderState.restore({
    required CategoryDefinition definition,
    required Product product,
    required Selection selection,
    Set<String> unavailableIngredientIds = const {},
  }) =>
      BuilderState._(definition, product, selection, unavailableIngredientIds);

  final CategoryDefinition definition;
  final Product product;
  final Selection selection;
  final Set<String> _unavailable;

  Map<String, ProductIngredient> get _defaults => {
    for (final d in product.defaults) d.ingredientId: d,
  };

  int qtyOf(String ingredientId) => selection.qtyOf(ingredientId);

  int defaultQtyOf(String ingredientId) => _defaults[ingredientId]?.qty ?? 0;

  /// Maximum selectable quantity. TEMP semantics: `maxQty` is the extra
  /// allowed above the default (OWNER_INPUTS #8, pending confirmation).
  int maxQtyOf(String ingredientId) =>
      defaultQtyOf(ingredientId) + definition.constraints.maxQty;

  bool canRemove(String ingredientId) {
    final q = qtyOf(ingredientId);
    if (q == 0) return false;
    final d = _defaults[ingredientId];
    return d == null || d.removable || q > d.qty;
  }

  bool canAdd(String ingredientId) => _check(ingredientId, 1) == null;

  Map<String, int> get extras => selection.extras(product.defaults);

  List<String> get removed => selection.removed(product.defaults);

  bool get isModified =>
      extras.isNotEmpty ||
      removed.isNotEmpty ||
      product.defaults.any((d) => qtyOf(d.ingredientId) != d.qty);

  BuilderResult add(String ingredientId) => _change(ingredientId, 1);

  BuilderResult remove(String ingredientId) => _change(ingredientId, -1);

  BuilderResult selectSize(String sizeId) {
    if (!definition.sizes.any((s) => s.id == sizeId)) {
      return BuilderResult.rejected(this, BuilderRejection.unknownChoice);
    }
    return BuilderResult.ok(_with(selection.copyWith(sizeId: sizeId)));
  }

  BuilderResult selectOption(String groupId, String choiceId) {
    final group = definition.optionGroups.where((g) => g.id == groupId);
    if (group.isEmpty || !group.first.choices.any((c) => c.id == choiceId)) {
      return BuilderResult.rejected(this, BuilderRejection.unknownChoice);
    }
    return BuilderResult.ok(
      _with(
        selection.copyWith(options: {...selection.options, groupId: choiceId}),
      ),
    );
  }

  BuilderState setNotes(String notes) =>
      _with(selection.copyWith(notes: notes));

  /// Back to the untouched product (keeps nothing).
  BuilderState reset() => BuilderState.open(
    definition: definition,
    product: product,
    unavailableIngredientIds: _unavailable,
  );

  BuilderRejection? _check(String id, int delta) {
    final next = qtyOf(id) + delta;
    if (delta > 0) {
      if (!definition.allowedIngredientIds.contains(id)) {
        return BuilderRejection.notAllowed;
      }
      if (_unavailable.contains(id)) return BuilderRejection.unavailable;
      if (next > maxQtyOf(id)) return BuilderRejection.maxQty;
    } else if (!canRemove(id)) {
      return BuilderRejection.notRemovable;
    }
    return null;
  }

  BuilderResult _change(String id, int delta) {
    final rejection = _check(id, delta);
    if (rejection != null) return BuilderResult.rejected(this, rejection);
    return BuilderResult.ok(
      _with(
        selection.copyWith(
          ingredients: {...selection.ingredients, id: qtyOf(id) + delta},
        ),
      ),
    );
  }

  BuilderState _with(Selection s) =>
      BuilderState._(definition, product, s, _unavailable);
}
