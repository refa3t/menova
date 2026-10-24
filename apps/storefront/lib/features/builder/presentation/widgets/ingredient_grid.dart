import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/theme/app_theme.dart';

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
    this.priceLabel,
  });

  final String id;
  final String name;
  final String imageUrl;
  final int qty;
  final int defaultQty;
  final bool canRemove;

  /// Price of one extra unit, e.g. "+ EGP 15".
  final String? priceLabel;

  IngredientTileState get state => qty == 0
      ? IngredientTileState.none
      : qty > defaultQty
      ? IngredientTileState.extra
      : IngredientTileState.included;
}

/// Topping cards (reference design): tap to add one; the − button removes
/// one when allowed. Defaults show a check, extras a counter.
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final item in items)
          SizedBox(
            width: 124,
            height: 158,
            child: _Tile(
              data: item,
              onAdd: () => onAdd(item.id),
              onRemove: () => onRemove(item.id),
            ),
          ),
      ],
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
    final state = data.state;
    final selected = state != IngredientTileState.none;
    return Semantics(
      button: true,
      label: '${data.name}، ${AppStrings.quantity} ${data.qty}',
      child: Material(
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.panel),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: state == IngredientTileState.extra ? 2.5 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 14, 8, 10),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Image.network(
                        data.imageUrl,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      data.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (data.priceLabel != null)
                      Text(
                        data.priceLabel!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                  ],
                ),
              ),
              PositionedDirectional(
                top: 6,
                end: 6,
                child: _Badge(state: state, qty: data.qty),
              ),
              if (data.canRemove)
                PositionedDirectional(
                  top: 0,
                  start: 0,
                  child: Semantics(
                    button: true,
                    label: '${AppStrings.remove} ${data.name}',
                    child: SizedBox.square(
                      dimension: 44,
                      child: IconButton(
                        onPressed: onRemove,
                        padding: EdgeInsets.zero,
                        icon: const CircleAvatar(
                          radius: 12,
                          backgroundColor: AppColors.surface,
                          child: Text(
                            '−',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
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
    final text = switch (state) {
      IngredientTileState.none => null,
      IngredientTileState.included => '✓',
      IngredientTileState.extra => '×$qty',
    };
    if (text == null) return const SizedBox.shrink();
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
