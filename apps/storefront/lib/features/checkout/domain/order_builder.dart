import 'dart:convert';

import 'package:core/core.dart';
import 'package:crypto/crypto.dart';
import 'package:pricing/pricing.dart';

import '../../../core/strings/app_strings.dart';

import '../../cart/domain/cart.dart';
import '../../menu/domain/menu.dart';

/// A price difference found when re-pricing the cart against fresh data
/// right before sending (scenario 4, CLAUDE.md 5.2).
class PriceDiff {
  const PriceDiff({
    required this.lineId,
    required this.productName,
    required this.shown,
    required this.current,
  });

  final String lineId;
  final String productName;

  /// Total the customer saw (piasters), null if the line could not be priced.
  final int? shown;

  /// Total from fresh data, null if the line is no longer available.
  final int? current;
}

/// Thrown when the cart cannot be turned into an order.
class OrderBuildException implements Exception {
  const OrderBuildException(this.lineId);
  final String lineId;
}

/// Turns a cart into the order a guest writes once (D-INFRA-01 = B). Every
/// price and name is frozen from [menu] (SEC-03). Pure: no I/O.
abstract final class OrderBuilder {
  /// Prices every line against [menu]; throws if a line cannot be priced or
  /// uses an unavailable product or ingredient.
  static List<OrderItem> items(Cart cart, Menu menu) => [
    for (final line in cart.lines) _item(line, menu),
  ];

  static OrderItem _item(CartLine line, Menu menu) {
    final s = line.selection;
    for (final c in menu.categories) {
      for (final p in c.products) {
        if (p.id != s.productId) continue;
        final def = c.definition;
        final PriceBreakdown price;
        try {
          price = priceItem(
            definition: def,
            product: p,
            ingredients: menu.ingredients,
            selection: s,
            itemQty: line.qty,
          );
        } on PricingException {
          throw OrderBuildException(line.lineId);
        }
        final extras = s.extras(p.defaults);
        if (extras.keys.any(
          (id) => menu.ingredients[id]?.isAvailable != true,
        )) {
          throw OrderBuildException(line.lineId);
        }
        final ids = {
          ...s.ingredients.keys,
          ...p.defaults.map((d) => d.ingredientId),
        };
        return OrderItem(
          lineId: line.lineId,
          selection: s,
          price: price,
          productName: p.name,
          sizeName: def.sizes.where((x) => x.id == s.sizeId).firstOrNull?.name,
          optionNames: {
            for (final g in def.optionGroups)
              if (g.choices.length > 1)
                for (final ch in g.choices)
                  if (ch.id == s.options[g.id]) ch.id: ch.name,
          },
          ingredientNames: {
            for (final id in ids) id: menu.ingredients[id]?.name ?? id,
          },
          defaultQty: {for (final d in p.defaults) d.ingredientId: d.qty},
        );
      }
    }
    throw OrderBuildException(line.lineId);
  }

  /// Lines whose price differs between what was shown and fresh data, or
  /// that are no longer available.
  static List<PriceDiff> diff(Cart cart, Menu shown, Menu fresh) {
    int? total(CartLine l, Menu m) {
      try {
        return _item(l, m).price.total;
      } on OrderBuildException {
        return null;
      }
    }

    String name(CartLine l) {
      for (final c in fresh.categories) {
        for (final p in c.products) {
          if (p.id == l.selection.productId) {
            return AppStrings.localized(p.name, p.names);
          }
        }
      }
      return l.selection.productId;
    }

    return [
      for (final l in cart.lines)
        if (total(l, shown) case final before)
          if (total(l, fresh) case final after
              when after != before || after == null)
            PriceDiff(
              lineId: l.lineId,
              productName: name(l),
              shown: before,
              current: after,
            ),
    ];
  }

  /// SHA-256 of the canonical order content (items, customer, notes). Same
  /// content gives the same hash; any change, including a price, differs.
  static String payloadHash({
    required List<OrderItem> items,
    required GuestCustomer customer,
    required String notes,
  }) {
    final canonical = _canonical({
      'items': [for (final i in items) i.toJson()],
      'customer': customer.toJson(),
      'notes': notes,
    });
    return sha256.convert(utf8.encode(jsonEncode(canonical))).toString();
  }

  /// Builds the order document. [deliveryFee] is TEMP until decision 5.
  static Order build({
    required String requestId,
    required String customerUid,
    required List<OrderItem> items,
    required GuestCustomer customer,
    required String notes,
    required DateTime now,
    int deliveryFee = 0,
  }) {
    final subtotal = items.fold<int>(0, (s, i) => s + i.price.total);
    return Order(
      id: requestId,
      requestId: requestId,
      payloadHash: payloadHash(items: items, customer: customer, notes: notes),
      customerUid: customerUid,
      customer: customer,
      items: items,
      status: OrderStatus.newOrder,
      paymentStatus: PaymentStatus.unpaid,
      paymentMethod: PaymentMethod.cash,
      deliveryFee: deliveryFee,
      total: subtotal + deliveryFee,
      definitionVersions: {
        for (final i in items)
          i.selection.categoryId: i.selection.definitionVersion,
      },
      rulesVersion: PricingRules.current.version,
      createdAt: now.toUtc().toIso8601String(),
      notes: notes,
    );
  }

  /// Sorts map keys recursively so equal content always encodes the same.
  static Object? _canonical(Object? v) => switch (v) {
    Map m => {
      for (final k in (m.keys.map((k) => '$k').toList()..sort()))
        k: _canonical(m[k]),
    },
    List l => [for (final x in l) _canonical(x)],
    _ => v,
  };
}
