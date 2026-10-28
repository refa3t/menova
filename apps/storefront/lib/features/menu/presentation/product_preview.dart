import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:product_builder/product_builder.dart';

import '../domain/menu.dart';

/// A product drawn without interaction: its defaults, or a given selection
/// (cart lines show what the customer actually built).
class ProductPreview extends StatelessWidget {
  const ProductPreview({
    super.key,
    required this.menu,
    required this.definition,
    required this.product,
    this.selection,
  });

  final Menu menu;
  final CategoryDefinition definition;
  final Product product;
  final Selection? selection;

  @override
  Widget build(BuildContext context) {
    final strategy = placementStrategies[definition.placement.strategy];
    final state = selection == null
        ? BuilderState.open(definition: definition, product: product)
        : BuilderState.restore(
            definition: definition,
            product: product,
            selection: selection!,
          );
    final base = menu.assets[state.activeBase.rawAssetId];
    if (strategy == null || base == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: BuilderCanvas(
        baseImageUrl: base.secureUrl,
        strategy: strategy,
        strategyByIngredient: strategiesByIngredient(definition.placement),
        placementParams: definition.placement.params,
        density: state.sizeDensity,
        layers: [
          for (final e in state.selection.ingredients.entries)
            if (e.value > 0)
              if (menu.ingredients[e.key] case final i?)
                if (menu.assets[i.assetId] case final a?)
                  CanvasLayer(
                    ingredientId: i.id,
                    imageUrls: [a.secureUrl, ...a.variants],
                    enterProfile:
                        definition.ingredientMotion[i.id]?.enter ??
                        defaultEnterProfile,
                    exitProfile:
                        definition.ingredientMotion[i.id]?.exit ??
                        defaultExitProfile,
                    qty: e.value,
                    layerOrder: definition.layerOverrides[i.id] ?? a.layerOrder,
                  ),
        ],
      ),
    );
  }
}
