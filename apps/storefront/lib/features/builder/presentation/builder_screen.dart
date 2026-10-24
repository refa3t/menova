import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_builder/product_builder.dart';

import '../../../core/strings/app_strings.dart';
import '../../menu/domain/menu.dart';
import '../../menu/presentation/menu_providers.dart';
import 'builder_providers.dart';

/// The orchestrator screen: wires the builder engine to the UI. Generic over
/// any category; everything comes from the definition and menu data.
class BuilderScreen extends ConsumerWidget {
  const BuilderScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: AppBar(),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.menuLoadError)),
        data: (menu) {
          final exists = menu.categories.any(
            (c) => c.products.any((p) => p.id == productId),
          );
          if (!exists) {
            return const Center(child: Text(AppStrings.productNotFound));
          }
          return _BuilderBody(menu: menu, productId: productId);
        },
      ),
    );
  }
}

class _BuilderBody extends ConsumerWidget {
  const _BuilderBody({required this.menu, required this.productId});

  final Menu menu;
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(builderProvider(productId));
    final controller = ref.read(builderProvider(productId).notifier);
    final def = state.definition;
    final strategy = placementStrategies[def.placement.strategy];
    final base = menu.assets[def.base.rawAssetId];
    if (strategy == null || base == null) {
      return const Center(child: Text(AppStrings.productNotFound));
    }
    final size = def.sizes.where((s) => s.id == state.selection.sizeId);

    List<String> urlsFor(Ingredient i) {
      final a = menu.assets[i.assetId];
      return a == null ? const [] : [a.secureUrl, ...a.variants];
    }

    final available = [
      for (final id in def.allowedIngredientIds)
        if (menu.ingredients[id] case final i? when urlsFor(i).isNotEmpty) i,
    ];

    void report(BuilderRejection? r) {
      final message = switch (r) {
        null => null,
        BuilderRejection.maxQty => AppStrings.maxQtyReached,
        BuilderRejection.notRemovable => AppStrings.notRemovable,
        BuilderRejection.unavailable => AppStrings.unavailable,
        BuilderRejection.notAllowed ||
        BuilderRejection.unknownChoice => AppStrings.notAllowed,
      };
      if (message == null) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final canvas = Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: BuilderCanvas(
          baseImageUrl: base.secureUrl,
          strategy: strategy,
          placementParams: def.placement.params,
          scale: size.isEmpty ? 1 : size.first.scale,
          layers: [
            for (final i in available)
              CanvasLayer(
                ingredientId: i.id,
                imageUrls: urlsFor(i),
                qty: state.qtyOf(i.id),
                layerOrder:
                    def.layerOverrides[i.id] ??
                    menu.assets[i.assetId]!.layerOrder,
              ),
          ],
        ),
      ),
    );

    final controls = <Widget>[
      Text(
        state.product.name,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      if (def.sizes.isNotEmpty) ...[
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            for (final s in def.sizes)
              ChoiceChip(
                label: Text(s.name),
                selected: s.id == state.selection.sizeId,
                onSelected: (_) => report(controller.selectSize(s.id)),
              ),
          ],
        ),
      ],
      const SizedBox(height: 16),
      for (final i in available)
        _IngredientRow(
          name: i.name,
          imageUrl: urlsFor(i).first,
          qty: state.qtyOf(i.id),
          canRemove: state.canRemove(i.id),
          onAdd: () => report(controller.add(i.id)),
          onRemove: () => report(controller.remove(i.id)),
        ),
      const SizedBox(height: 8),
      OutlinedButton(
        onPressed: state.isModified ? controller.reset : null,
        child: const Text(AppStrings.reset),
      ),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        // Narrow screens scroll as one page so the controls are never
        // squeezed out by the canvas.
        if (box.maxWidth >= 840) {
          return Row(
            children: [
              Expanded(flex: 3, child: Center(child: canvas)),
              Expanded(
                flex: 2,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: controls,
                ),
              ),
            ],
          );
        }
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            Center(child: canvas),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: controls,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.canRemove,
    required this.onAdd,
    required this.onRemove,
  });

  final String name;
  final String imageUrl;
  final int qty;
  final bool canRemove;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: SizedBox.square(dimension: 40, child: Image.network(imageUrl)),
      title: Text(name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QtyButton(
            label: '−',
            semantics: AppStrings.remove,
            onPressed: canRemove ? onRemove : null,
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _QtyButton(label: '+', semantics: AppStrings.add, onPressed: onAdd),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({
    required this.label,
    required this.semantics,
    required this.onPressed,
  });

  final String label;
  final String semantics;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          textStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
        ),
        child: Text(label),
      ),
    );
  }
}
