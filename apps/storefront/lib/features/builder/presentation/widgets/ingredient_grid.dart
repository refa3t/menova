import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';

/// Display state of one ingredient tile (P1-C03).
enum IngredientTileState { none, included, extra }

/// What the grid shows for one ingredient.
class IngredientTileData {
  const IngredientTileData({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.qty,
    required this.defaultQty,
    required this.canRemove,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int qty;
  final int defaultQty;
  final bool canRemove;

  IngredientTileState get state => qty == 0
      ? IngredientTileState.none
      : qty > defaultQty
      ? IngredientTileState.extra
      : IngredientTileState.included;
}

/// Ingredient grid: tap a tile to add one; the − button removes one when
/// allowed. Default ingredients show a check, extras a ring and counter.
class IngredientGrid extends StatelessWidget {
  const IngredientGrid({
    super.key,
    required this.items,
    required this.onAdd,
    required this.onRemove,
  });

  final List<IngredientTileData> items;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 124,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.78,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _Tile(
        data: items[i],
        onAdd: () => onAdd(items[i].id),
        onRemove: () => onRemove(items[i].id),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.data,
    required this.onAdd,
    required this.onRemove,
  });

  final IngredientTileData data;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = data.state;
    final border = switch (state) {
      IngredientTileState.none => BorderSide(color: scheme.outlineVariant),
      IngredientTileState.included => BorderSide(color: scheme.primary),
      IngredientTileState.extra => BorderSide(color: scheme.primary, width: 3),
    };
    return Semantics(
      button: true,
      label: '${data.name}، ${AppStrings.quantity} ${data.qty}',
      child: Material(
        color: state == IngredientTileState.none
            ? scheme.surface
            : scheme.primaryContainer.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: border,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                child: Column(
                  children: [
                    Expanded(
                      child: Image.network(
                        data.imageUrl,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 4,
                start: 4,
                child: _Badge(state: state, qty: data.qty),
              ),
              if (data.canRemove)
                PositionedDirectional(
                  top: 0,
                  end: 0,
                  child: Semantics(
                    button: true,
                    label: '${AppStrings.remove} ${data.name}',
                    child: SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        onPressed: onRemove,
                        padding: EdgeInsets.zero,
                        icon: CircleAvatar(
                          radius: 13,
                          backgroundColor: scheme.surface,
                          child: Text(
                            '−',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.state, required this.qty});

  final IngredientTileState state;
  final int qty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = switch (state) {
      IngredientTileState.none => null,
      IngredientTileState.included => '✓',
      IngredientTileState.extra => '×$qty',
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: scheme.onPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
