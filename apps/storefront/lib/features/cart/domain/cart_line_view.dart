import 'package:core/core.dart';
import 'package:pricing/pricing.dart';

import '../../menu/domain/menu.dart';
import 'cart.dart';

/// A cart line resolved against the current menu, for display. Generic: it
/// knows sizes, options and ingredients, never a specific category.
class CartLineView {
  const CartLineView({
    required this.line,
    required this.available,
    this.category,
    this.product,
    this.sizeName,
    this.optionNames = const [],
    this.extras = const [],
    this.removed = const [],
    this.price,
  });

  final CartLine line;

  /// False when the product, an ingredient or the price is no longer valid.
  final bool available;
  final MenuCategory? category;
  final Product? product;
  final String? sizeName;
  final List<String> optionNames;

  /// (name, extra qty) for ingredients above the default.
  final List<(String, int)> extras;

  /// Names of removed defaults, shown as "بدون X".
  final List<String> removed;

  /// Live price for the line quantity; frozen only at order confirmation.
  final PriceBreakdown? price;

  static CartLineView resolve(CartLine line, Menu menu) {
    final s = line.selection;
    for (final c in menu.categories) {
      for (final p in c.products) {
        if (p.id != s.productId) continue;
        final def = c.definition;
        String name(String id) => menu.ingredients[id]?.name ?? id;
        PriceBreakdown? price;
        try {
          price = priceItem(
            definition: def,
            product: p,
            ingredients: menu.ingredients,
            selection: s,
            itemQty: line.qty,
          );
        } on PricingException {
          price = null;
        }
        final extras = s.extras(p.defaults);
        final unavailable = extras.keys.any(
          (id) => menu.ingredients[id]?.isAvailable != true,
        );
        return CartLineView(
          line: line,
          available: price != null && !unavailable,
          category: c,
          product: p,
          sizeName: def.sizes.where((x) => x.id == s.sizeId).firstOrNull?.name,
          optionNames: [
            for (final g in def.optionGroups)
              // Show only real choices, not the default of a 1-choice group.
              if (g.choices.length > 1)
                if (g.choices.where((c) => c.id == s.options[g.id]).firstOrNull
                    case final choice?)
                  choice.name,
          ],
          extras: [for (final e in extras.entries) (name(e.key), e.value)],
          removed: [for (final id in s.removed(p.defaults)) name(id)],
          price: price,
        );
      }
    }
    return CartLineView(line: line, available: false);
  }
}
