import 'package:core/core.dart';

import 'pricing.dart';

/// What an order brings to an offer (P3-09): its items' totals by category
/// (each already rounded), its delivery fee, and when it is placed.
class OfferBasis {
  const OfferBasis({
    required this.itemsByCategory,
    this.deliveryFee = 0,
    required this.atMs,
  });

  factory OfferBasis.of(
    Iterable<OrderItem> items, {
    Piasters deliveryFee = 0,
    required int atMs,
  }) {
    final by = <String, Piasters>{};
    for (final i in items) {
      by[i.selection.categoryId] =
          (by[i.selection.categoryId] ?? 0) + i.price.total;
    }
    return OfferBasis(
      itemsByCategory: by,
      deliveryFee: deliveryFee,
      atMs: atMs,
    );
  }

  final Map<String, Piasters> itemsByCategory;
  final Piasters deliveryFee;
  final int atMs;

  Piasters get itemsTotal => itemsByCategory.values.fold(0, (a, b) => a + b);
}

/// Why an offer gives an order nothing.
enum OfferMiss {
  inactive,
  notStarted,
  ended,
  usedUp,
  belowMinimum,
  noEligibleItems,
  nothingToTake,
}

/// What an offer gives an order: a discount, or why there is none.
class OfferResult {
  const OfferResult.discount(this.discount) : miss = null;
  const OfferResult.miss(OfferMiss this.miss) : discount = 0;

  final Piasters discount;
  final OfferMiss? miss;

  bool get applies => miss == null;
}

/// The discount [offer] gives an order (P3-09, CLAUDE.md 5.1): a percent
/// or an amount off the eligible items (all of them, or one category's),
/// or the delivery fee for free delivery. A percent is rounded once, half
/// up, to the pricing step; a cap stops it; it never takes more than what
/// it comes from, so the items never go below zero. Pure (ARC-04). Must
/// match `validOrderOffer` in firestore.rules.
OfferResult offerDiscount(
  Offer offer,
  OfferBasis order, {
  PricingRules rules = PricingRules.current,
}) {
  if (!offer.isActive) return const OfferResult.miss(OfferMiss.inactive);
  if (offer.startsAtMs case final s? when order.atMs < s) {
    return const OfferResult.miss(OfferMiss.notStarted);
  }
  if (offer.endsAtMs case final e? when order.atMs >= e) {
    return const OfferResult.miss(OfferMiss.ended);
  }
  if (offer.maxUses case final m? when offer.uses >= m) {
    return const OfferResult.miss(OfferMiss.usedUp);
  }
  final items = order.itemsTotal;
  if (items < offer.minSubtotal) {
    return const OfferResult.miss(OfferMiss.belowMinimum);
  }
  final category = offer.categoryId;
  final eligible = category == null
      ? items
      : order.itemsByCategory[category] ?? 0;
  if (eligible <= 0) return const OfferResult.miss(OfferMiss.noEligibleItems);

  var discount = switch (offer.kind) {
    OfferKind.percent => _percentOf(eligible, offer.value, rules.roundingStep),
    OfferKind.amount => offer.value,
    OfferKind.freeDelivery => order.deliveryFee,
  };
  if (offer.maxDiscount case final cap? when discount > cap) discount = cap;
  final from = offer.kind == OfferKind.freeDelivery
      ? order.deliveryFee
      : eligible;
  if (discount > from) discount = from;
  return discount > 0
      ? OfferResult.discount(discount)
      : const OfferResult.miss(OfferMiss.nothingToTake);
}

/// [amount] × [percent] / 100, rounded once (half up) to [step].
Piasters _percentOf(Piasters amount, int percent, Piasters step) {
  final s = step < 1 ? 1 : step;
  return (amount * percent + s * 50) ~/ (s * 100) * s;
}

/// The one offer an order gets (one per order, CLAUDE.md 5.1): the largest
/// discount; on a tie an automatic offer before a coupon (so the coupon is
/// not used up), then the lower id. Null when none applies.
({Offer offer, Piasters discount})? bestOffer(
  Iterable<Offer> offers,
  OfferBasis order, {
  PricingRules rules = PricingRules.current,
}) {
  ({Offer offer, Piasters discount})? best;
  for (final o in offers) {
    final r = offerDiscount(o, order, rules: rules);
    if (!r.applies) continue;
    final b = best;
    if (b == null ||
        r.discount > b.discount ||
        (r.discount == b.discount && _before(o, b.offer))) {
      best = (offer: o, discount: r.discount);
    }
  }
  return best;
}

bool _before(Offer a, Offer b) =>
    a.isCoupon != b.isCoupon ? !a.isCoupon : a.id.compareTo(b.id) < 0;
