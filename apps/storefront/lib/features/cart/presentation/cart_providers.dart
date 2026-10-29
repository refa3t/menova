import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/cart.dart';

/// Device storage, provided from `main` once it is ready.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('Override in main()'),
);

final cartProvider = NotifierProvider<CartController, Cart>(CartController.new);

class CartController extends Notifier<Cart> {
  static const _storageKey = 'cart.v1';
  final _random = Random();

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  /// Restores the saved cart (P1-E03). A corrupt entry yields an empty cart.
  @override
  Cart build() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return Cart.empty;
    try {
      return Cart.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return Cart.empty;
    }
  }

  @override
  set state(Cart value) {
    super.state = value;
    _prefs.setString(_storageKey, jsonEncode(value.toJson()));
  }

  /// Adds the item in a single atomic step, before any animation runs
  /// (ARC-07). Returns the new line id.
  String add(Selection selection, {int qty = 1}) {
    final id =
        '${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(0x7fffffff)}';
    state = state.add(CartLine(lineId: id, selection: selection, qty: qty));
    // An identical line absorbs the new one: return the line that holds it.
    return state.lines.firstWhere((l) => l.selection == selection).lineId;
  }

  /// Updates an existing line without duplicating it (AC-18).
  void replace(String lineId, Selection selection) =>
      state = state.replace(lineId, selection);

  void setQty(String lineId, int qty) => state = state.setQty(lineId, qty);

  void remove(String lineId) => state = state.remove(lineId);

  void clear() => state = Cart.empty;
}
