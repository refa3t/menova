import 'package:core/core.dart';
import 'package:pricing/pricing.dart';

/// What reception needs to re-price an order: current definitions, products
/// and ingredients from Firestore and the bundled definitions.
class PricingData {
  const PricingData({
    required this.definitions,
    required this.products,
    required this.ingredients,
  });

  final Map<String, CategoryDefinition> definitions;
  final Map<String, Product> products;
  final Map<String, Ingredient> ingredients;
}

/// Result of re-pricing an order (amended SEC-02, D-INFRA-01 = B).
class OrderVerification {
  const OrderVerification({required this.computedTotal, required this.issues});

  /// Total recomputed from current data, null if any line can't be priced.
  final int? computedTotal;

  /// Human-readable problems (line ids / reasons); empty means it matches.
  final List<String> issues;

  bool get matches => issues.isEmpty;
}

/// Re-prices every line with the shared pricing engine and compares it with
/// the snapshot the guest wrote. A mismatch can be tampering or a price that
/// changed after the order was placed; staff decide (the card is flagged).
OrderVerification verifyOrder(Order order, PricingData data) {
  final issues = <String>[];
  var total = 0;
  var priced = true;
  for (final item in order.items) {
    final s = item.selection;
    final def = data.definitions[s.categoryId];
    final product = data.products[s.productId];
    if (def == null || product == null) {
      issues.add('${item.productName}: unknown product');
      priced = false;
      continue;
    }
    try {
      final computed = priceItem(
        definition: def,
        product: product,
        ingredients: data.ingredients,
        selection: s,
        itemQty: item.price.itemQty,
      );
      total += computed.total;
      if (computed.total != item.price.total) {
        issues.add(
          '${item.productName}: ${item.price.total} ≠ ${computed.total}',
        );
      }
    } on PricingException catch (e) {
      issues.add('${item.productName}: ${e.code}');
      priced = false;
    }
  }
  final snapshotSum = order.itemsTotal;
  // P3-09: the discount again, from the offer frozen with the order.
  var discount = 0;
  if (order.offer case final offer?) {
    final r = offerDiscount(
      offer.asOffer,
      OfferBasis.of(order.items, deliveryFee: order.deliveryFee, atMs: 0),
    );
    discount = r.discount;
    if (r.discount != order.discount) {
      issues.add('discount ${order.discount} ≠ ${r.discount}');
    }
  } else if (order.discount != 0) {
    issues.add('discount ${order.discount} without an offer');
  }
  if (snapshotSum - order.discount + order.deliveryFee != order.total) {
    issues.add(
      'total ${order.total} ≠ items $snapshotSum - discount + delivery',
    );
  }
  return OrderVerification(
    computedTotal: priced ? total - discount + order.deliveryFee : null,
    issues: issues,
  );
}
