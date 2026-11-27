import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_builder/product_builder.dart';

import '../../cart/presentation/cart_providers.dart';
import '../../menu/presentation/menu_providers.dart';

/// Which builder is open: a product, or an existing cart line being edited.
typedef BuilderKey = ({String productId, String? lineId});

/// The single builder provider (P1-B01), one per open product or line.
/// Requires the menu to be loaded; the screen reads it only once
/// `menuProvider` has data.
final builderProvider = NotifierProvider.autoDispose
    .family<BuilderController, BuilderState, BuilderKey>(BuilderController.new);

class BuilderController extends Notifier<BuilderState> {
  BuilderController(this.key);

  final BuilderKey key;

  @override
  BuilderState build() {
    final menu = ref.watch(menuProvider).requireValue;
    for (final c in menu.categories) {
      for (final p in c.products) {
        if (p.id == key.productId) {
          final unavailable = {
            for (final id in menu.ingredients.keys)
              if (!menu.ingredientAvailable(id)) id,
          };
          // The menu is seen again when a stopped record comes back: keep
          // what the guest is building. Editing a cart line restores what
          // was built (AC-18).
          final building = stateOrNull?.selection;
          final line = key.lineId == null
              ? null
              : ref.read(cartProvider).line(key.lineId!);
          final saved = building ?? line?.selection;
          return saved == null
              ? BuilderState.open(
                  definition: c.definition,
                  product: p,
                  unavailableIngredientIds: unavailable,
                )
              : BuilderState.restore(
                  definition: c.definition,
                  product: p,
                  selection: saved,
                  unavailableIngredientIds: unavailable,
                );
        }
      }
    }
    throw StateError('Unknown product ${key.productId}');
  }

  /// Applies a change; returns the rejection reason if it was refused.
  BuilderRejection? _apply(BuilderResult r) {
    state = r.state;
    return r.rejection;
  }

  BuilderRejection? add(String ingredientId) => _apply(state.add(ingredientId));

  BuilderRejection? remove(String ingredientId) =>
      _apply(state.remove(ingredientId));

  BuilderRejection? selectSize(String sizeId) =>
      _apply(state.selectSize(sizeId));

  BuilderRejection? selectOption(String groupId, String choiceId) =>
      _apply(state.selectOption(groupId, choiceId));

  void setNotes(String notes) => state = state.setNotes(notes);

  void reset() => state = state.reset();
}
