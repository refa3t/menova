import 'package:core/core.dart';

/// Developer-owned pricing rules (CLAUDE.md 4.1). Pure data.
class PricingRules {
  const PricingRules({required this.version, required this.roundingStep});

  final int version;

  /// The item total is rounded once to the nearest multiple of this
  /// (piasters). 100 = nearest 1 EGP.
  final Piasters roundingStep;

  /// Owner-approved (P0-05): round each item total to the nearest 1 EGP.
  static const current = PricingRules(version: 2, roundingStep: 100);
}

/// Why an item cannot be priced. The server rejects these orders.
class PricingException implements Exception {
  const PricingException(this.code, [this.refId]);

  /// `maxQty`, `notAllowed`, `unknownSize`, `unknownOption`, `badQty`.
  final String code;
  final String? refId;

  @override
  String toString() =>
      'PricingException($code${refId == null ? '' : ', $refId'})';
}

/// Prices one item (CLAUDE.md 5.1):
///
/// ```
/// unit  = basePrice + sizeDelta + Σ optionDeltas
///       + Σ extraPrice × sizeMultiplier × extraQty − Σ refunds
/// total = round(max(0, unit) × itemQty)      // rounded once
/// extraQty = max(0, selectedQty − defaultQty)
/// ```
///
/// Defaults are always included in the base price and never charged as
/// extras. A refund applies only to removed default units of an ingredient
/// with `refundOnRemove`, and never exceeds that ingredient's extra price.
/// Pure function: no state, no I/O, no Flutter (ARC-04).
PriceBreakdown priceItem({
  required CategoryDefinition definition,
  required Product product,
  required Map<String, Ingredient> ingredients,
  required Selection selection,
  required int itemQty,
  PricingRules rules = PricingRules.current,
}) {
  if (itemQty < 1) throw const PricingException('badQty');
  final lines = <PriceLine>[
    PriceLine(kind: PriceLineKind.base, amount: product.basePrice),
  ];

  final sizeId = selection.sizeId;
  if (sizeId != null) {
    if (!definition.sizes.any((s) => s.id == sizeId)) {
      throw PricingException('unknownSize', sizeId);
    }
    final delta = product.sizeDeltas[sizeId] ?? 0;
    if (delta != 0) {
      lines.add(
        PriceLine(kind: PriceLineKind.size, refId: sizeId, amount: delta),
      );
    }
  }

  for (final e in selection.options.entries) {
    final group = definition.optionGroups.where((g) => g.id == e.key);
    if (group.isEmpty || !group.first.choices.any((c) => c.id == e.value)) {
      throw PricingException('unknownOption', e.value);
    }
    final delta = product.optionDeltas[e.value] ?? 0;
    if (delta != 0) {
      lines.add(
        PriceLine(kind: PriceLineKind.option, refId: e.value, amount: delta),
      );
    }
  }

  final defaults = {for (final d in product.defaults) d.ingredientId: d};
  final ids = {...selection.ingredients.keys, ...defaults.keys}.toList()
    ..sort();
  for (final id in ids) {
    final selected = selection.qtyOf(id);
    final d = defaults[id];
    final defaultQty = d?.qty ?? 0;
    if (selected > defaultQty) {
      if (!definition.allowedIngredientIds.contains(id)) {
        throw PricingException('notAllowed', id);
      }
      // maxQty is the extra allowed above the default (owner, P0-05).
      if (selected > defaultQty + definition.constraints.maxQty) {
        throw PricingException('maxQty', id);
      }
      final ingredient = ingredients[id];
      if (ingredient == null) throw PricingException('notAllowed', id);
      final extraQty = selected - defaultQty;
      final unit = _unitExtra(ingredient, sizeId);
      lines.add(
        PriceLine(
          kind: PriceLineKind.extra,
          refId: id,
          qty: extraQty,
          amount: unit * extraQty,
        ),
      );
    } else if (selected < defaultQty && d != null && d.refundOnRemove) {
      final ingredient = ingredients[id];
      final cap = ingredient == null ? 0 : _unitExtra(ingredient, sizeId);
      final perUnit = d.refundAmount < cap ? d.refundAmount : cap;
      final removedQty = defaultQty - selected;
      if (perUnit > 0) {
        lines.add(
          PriceLine(
            kind: PriceLineKind.refund,
            refId: id,
            qty: removedQty,
            amount: -perUnit * removedQty,
          ),
        );
      }
    }
  }

  final unitSubtotal = lines.fold<int>(0, (s, l) => s + l.amount);
  final raw = (unitSubtotal < 0 ? 0 : unitSubtotal) * itemQty;
  final total = _roundToStep(raw, rules.roundingStep);
  return PriceBreakdown(
    lines: lines,
    unitSubtotal: unitSubtotal,
    itemQty: itemQty,
    rounding: total - raw,
    total: total,
    ruleVersion: rules.version,
  );
}

/// Extra price of one unit for the size, in whole piasters (half up).
Piasters _unitExtra(Ingredient i, String? sizeId) =>
    (i.extraPrice * i.multiplierFor(sizeId)).round();

/// Nearest multiple of [step], halves rounded up.
Piasters _roundToStep(Piasters amount, Piasters step) {
  if (step <= 1) return amount;
  return ((amount + step ~/ 2) ~/ step) * step;
}

/// Delivery fee for a road distance (owner rules, P0-05): every started
/// kilometer costs [DeliverySettings.perKm], never below
/// [DeliverySettings.minFee]. Throws `PricingException('outOfRange')`
/// beyond [DeliverySettings.maxDistanceMeters]. Added after the items
/// total (CLAUDE.md 5.1). Must match `deliveryFeeOk` in firestore.rules.
Piasters deliveryFee(int distanceMeters, DeliverySettings settings) {
  if (distanceMeters < 0) throw const PricingException('badDistance');
  if (distanceMeters > settings.maxDistanceMeters) {
    throw const PricingException('outOfRange');
  }
  final km = (distanceMeters + 999) ~/ 1000;
  final fee = km * settings.perKm;
  return fee < settings.minFee ? settings.minFee : fee;
}
