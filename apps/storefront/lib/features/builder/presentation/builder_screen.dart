import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_builder/product_builder.dart';

import '../../../core/strings/app_strings.dart';
import '../../menu/domain/menu.dart';
import '../../menu/presentation/menu_providers.dart';
import 'builder_providers.dart';
import 'widgets/choice_selectors.dart';
import 'widgets/ingredient_grid.dart';
import 'widgets/notes_field.dart';

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

class _BuilderBody extends ConsumerStatefulWidget {
  const _BuilderBody({required this.menu, required this.productId});

  final Menu menu;
  final String productId;

  @override
  ConsumerState<_BuilderBody> createState() => _BuilderBodyState();
}

class _BuilderBodyState extends ConsumerState<_BuilderBody> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache every asset of the category when the product opens (5.6), so
    // added ingredients appear without a loading gap.
    final def = ref.read(builderProvider(widget.productId)).definition;
    final urls = <String>{
      for (final id in def.allowedIngredientIds)
        if (widget.menu.ingredients[id] case final i?)
          if (widget.menu.assets[i.assetId] case final a?) ...[
            a.secureUrl,
            ...a.variants,
          ],
      for (final a in widget.menu.assets.values)
        if (a.kind == 'base' && a.allowedCategoryIds.contains(def.id))
          a.secureUrl,
    };
    for (final url in urls) {
      precacheImage(NetworkImage(url), context, onError: (_, _) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final productId = widget.productId;
    final state = ref.watch(builderProvider(productId));
    final controller = ref.read(builderProvider(productId).notifier);
    final def = state.definition;
    final strategy = placementStrategies[def.placement.strategy];
    final base = menu.assets[state.activeBase.rawAssetId];
    if (strategy == null || base == null) {
      return const Center(child: Text(AppStrings.productNotFound));
    }

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
          scale: state.sizeScale,
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
      const SizedBox(height: 16),
      SizeSelector(
        sizes: def.sizes,
        selectedId: state.selection.sizeId,
        onSelected: (id) => report(controller.selectSize(id)),
      ),
      for (final g in def.optionGroups) ...[
        const SizedBox(height: 16),
        OptionGroupSelector(
          group: g,
          selectedId: state.selection.options[g.id],
          onSelected: (id) => report(controller.selectOption(g.id, id)),
        ),
      ],
      const SizedBox(height: 20),
      Text(
        AppStrings.ingredients,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      IngredientGrid(
        items: [
          for (final i in available)
            IngredientTileData(
              id: i.id,
              name: i.name,
              imageUrl: urlsFor(i).first,
              qty: state.qtyOf(i.id),
              defaultQty: state.defaultQtyOf(i.id),
              canRemove: state.canRemove(i.id),
            ),
        ],
        onAdd: (id) => report(controller.add(id)),
        onRemove: (id) => report(controller.remove(id)),
      ),
      const SizedBox(height: 16),
      NotesField(
        initial: state.selection.notes,
        onChanged: controller.setNotes,
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: state.isModified ? controller.reset : null,
        style: OutlinedButton.styleFrom(minimumSize: const Size(44, 44)),
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
