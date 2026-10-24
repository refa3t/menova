import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:product_builder/product_builder.dart';

import '../domain/menu.dart';

/// A product drawn with its default ingredients (no interaction).
class ProductPreview extends StatelessWidget {
  const ProductPreview({
    super.key,
    required this.menu,
    required this.definition,
    required this.product,
  });

  final Menu menu;
  final CategoryDefinition definition;
  final Product product;

  @override
  Widget build(BuildContext context) {
    final strategy = placementStrategies[definition.placement.strategy];
    final base = menu.assets[definition.base.rawAssetId];
    if (strategy == null || base == null) return const SizedBox.shrink();
    return IgnorePointer(
      child: BuilderCanvas(
        baseImageUrl: base.secureUrl,
        strategy: strategy,
        placementParams: definition.placement.params,
        layers: [
          for (final d in product.defaults)
            if (menu.ingredients[d.ingredientId] case final i?)
              if (menu.assets[i.assetId] case final a?)
                CanvasLayer(
                  ingredientId: i.id,
                  imageUrls: [a.secureUrl, ...a.variants],
                  qty: d.qty,
                  layerOrder: definition.layerOverrides[i.id] ?? a.layerOrder,
                ),
        ],
      ),
    );
  }
}
