import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pricing/pricing.dart';

import '../../menu/presentation/menu_providers.dart';
import 'builder_providers.dart';

/// The orchestrator links the builder's Selection to the pricing engine
/// (ARC-03): neither engine knows the other. Null when the selection cannot
/// be priced (the builder already prevents that in practice).
final priceProvider = Provider.autoDispose.family<PriceBreakdown?, String>((
  ref,
  productId,
) {
  final state = ref.watch(builderProvider(productId));
  final menu = ref.watch(menuProvider).requireValue;
  try {
    return priceItem(
      definition: state.definition,
      product: state.product,
      ingredients: menu.ingredients,
      selection: state.selection,
      itemQty: 1,
    );
  } on PricingException {
    return null;
  }
});
