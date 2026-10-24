import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_builder/product_builder.dart';

import '../../menu/presentation/menu_providers.dart';

/// The single builder provider (P1-B01), one per open product. Requires the
/// menu to be loaded; the screen only reads it once `menuProvider` has data.
final builderProvider = NotifierProvider.autoDispose
    .family<BuilderController, BuilderState, String>(BuilderController.new);

class BuilderController extends Notifier<BuilderState> {
  BuilderController(this.productId);

  final String productId;

  @override
  BuilderState build() {
    final menu = ref.watch(menuProvider).requireValue;
    for (final c in menu.categories) {
      for (final p in c.products) {
        if (p.id == productId) {
          return BuilderState.open(
            definition: c.definition,
            product: p,
            unavailableIngredientIds: {
              for (final i in menu.ingredients.values)
                if (!i.isAvailable) i.id,
            },
          );
        }
      }
    }
    throw StateError('Unknown product $productId');
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

  void reset() => state = state.reset();
}
