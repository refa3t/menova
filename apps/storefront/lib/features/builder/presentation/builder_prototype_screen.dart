import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:product_builder/product_builder.dart';

import '../../../core/strings/app_strings.dart';
import '../../menu/domain/menu.dart';
import '../../menu/presentation/menu_providers.dart';

/// P1-B00 drawing prototype (gate). Generic over any category: everything
/// comes from the definition and the menu data. No pricing here.
class BuilderPrototypeScreen extends ConsumerStatefulWidget {
  const BuilderPrototypeScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<BuilderPrototypeScreen> createState() =>
      _BuilderPrototypeScreenState();
}

class _BuilderPrototypeScreenState
    extends ConsumerState<BuilderPrototypeScreen> {
  Map<String, int>? _qty;
  String? _sizeId;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: AppBar(),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.menuLoadError)),
        data: (menu) {
          final found = _find(menu);
          if (found == null) {
            return const Center(child: Text(AppStrings.productNotFound));
          }
          final (category, product) = found;
          return _build(context, menu, category.definition, product);
        },
      ),
    );
  }

  (MenuCategory, Product)? _find(Menu menu) {
    for (final c in menu.categories) {
      for (final p in c.products) {
        if (p.id == widget.productId) return (c, p);
      }
    }
    return null;
  }

  Widget _build(
    BuildContext context,
    Menu menu,
    CategoryDefinition def,
    Product product,
  ) {
    final defaults = {for (final d in product.defaults) d.ingredientId: d};
    final qty = _qty ??= {
      for (final d in product.defaults) d.ingredientId: d.qty,
    };
    final strategy = placementStrategies[def.placement.strategy];
    final base = menu.assets[def.base.rawAssetId];
    if (strategy == null || base == null) {
      return const Center(child: Text(AppStrings.productNotFound));
    }
    final size =
        def.sizes.where((s) => s.id == _sizeId).firstOrNull ??
        def.sizes.lastOrNull;

    List<String> urlsFor(Ingredient i) {
      final a = menu.assets[i.assetId];
      return a == null ? const [] : [a.secureUrl, ...a.variants];
    }

    final available = [
      for (final id in def.allowedIngredientIds)
        if (menu.ingredients[id] case final i? when urlsFor(i).isNotEmpty) i,
    ];

    void change(Ingredient i, int delta) {
      final d = defaults[i.id];
      final current = qty[i.id] ?? 0;
      final next = current + delta;
      if (next < 0) return;
      if (delta < 0 && d != null && !d.removable && next < d.qty) return;
      // TEMP: maxQty read as "extra above default" (OWNER_INPUTS #8).
      if (next > (d?.qty ?? 0) + def.constraints.maxQty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(AppStrings.maxQtyReached)),
          );
        return;
      }
      setState(() => qty[i.id] = next);
    }

    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 840;
        final canvas = Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: BuilderCanvas(
              baseImageUrl: base.secureUrl,
              strategy: strategy,
              placementParams: def.placement.params,
              scale: size?.scale ?? 1,
              layers: [
                for (final i in available)
                  CanvasLayer(
                    ingredientId: i.id,
                    imageUrls: urlsFor(i),
                    qty: qty[i.id] ?? 0,
                    layerOrder:
                        def.layerOverrides[i.id] ??
                        menu.assets[i.assetId]!.layerOrder,
                  ),
              ],
            ),
          ),
        );
        final controls = <Widget>[
          Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
          if (def.sizes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                for (final s in def.sizes)
                  ChoiceChip(
                    label: Text(s.name),
                    selected: s.id == size?.id,
                    onSelected: (_) => setState(() => _sizeId = s.id),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          for (final i in available)
            _IngredientRow(
              name: i.name,
              imageUrl: urlsFor(i).first,
              qty: qty[i.id] ?? 0,
              canRemove:
                  (qty[i.id] ?? 0) > 0 && (defaults[i.id]?.removable ?? true),
              onAdd: () => change(i, 1),
              onRemove: () => change(i, -1),
            ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => setState(() => _qty = null),
            child: const Text(AppStrings.reset),
          ),
        ];
        // Narrow screens scroll as one page so the controls are never
        // squeezed out by the canvas.
        return wide
            ? Row(
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
              )
            : ListView(
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
