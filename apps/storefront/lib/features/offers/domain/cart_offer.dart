import 'package:core/core.dart';
import 'package:pricing/pricing.dart';

import '../../cart/domain/cart.dart';
import '../../cart/domain/cart_line_view.dart';
import '../../menu/domain/menu.dart';

/// What the cart brings to an offer (P3-09): each line's current total by
/// its category, the delivery fee, and now. Lines that cannot be priced
/// count for nothing (they block checkout anyway).
OfferBasis cartBasis(
  Cart cart,
  Menu menu, {
  Piasters deliveryFee = 0,
  required DateTime now,
}) {
  final by = <String, Piasters>{};
  for (final l in cart.lines) {
    final total = CartLineView.resolve(l, menu).price?.total;
    if (total == null) continue;
    final c = l.selection.categoryId;
    by[c] = (by[c] ?? 0) + total;
  }
  return OfferBasis(
    itemsByCategory: by,
    deliveryFee: deliveryFee,
    atMs: now.millisecondsSinceEpoch,
  );
}

/// The offer an order gets and what it takes off, as shown to the guest
/// and checked again right before sending.
typedef AppliedOffer = ({Offer offer, Piasters discount});
