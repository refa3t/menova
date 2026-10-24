import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/cart.dart';

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

class CartController extends Notifier<Cart> {
  final _random = Random();

  @override
  Cart build() => Cart.empty;

  /// Adds the item in a single atomic step, before any animation runs
  /// (ARC-07). Returns the new line id.
  String add(Selection selection, {int qty = 1}) {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    state = state.add(CartLine(lineId: id, selection: selection, qty: qty));
    return id;
  }

  /// Updates an existing line without duplicating it (AC-18).
  void replace(String lineId, Selection selection) =>
      state = state.replace(lineId, selection);

  void setQty(String lineId, int qty) => state = state.setQty(lineId, qty);

  void remove(String lineId) => state = state.remove(lineId);

  void clear() => state = Cart.empty;
}
