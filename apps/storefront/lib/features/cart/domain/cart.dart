import 'package:core/core.dart';

/// One cart line: what the customer built and how many. Prices are not
/// stored here (DATA-01); they are computed from the selection and frozen
/// only when the order is confirmed (SEC-03).
class CartLine {
  const CartLine({
    required this.lineId,
    required this.selection,
    required this.qty,
  });

  final String lineId;
  final Selection selection;
  final int qty;

  CartLine copyWith({Selection? selection, int? qty}) => CartLine(
    lineId: lineId,
    selection: selection ?? this.selection,
    qty: qty ?? this.qty,
  );

  factory CartLine.fromJson(Json j) => CartLine(
    lineId: j['lineId'] as String,
    selection: Selection.fromJson(j['selection'] as Json),
    qty: j['qty'] as int,
  );

  Json toJson() => {
    'lineId': lineId,
    'selection': selection.toJson(),
    'qty': qty,
  };
}

/// The cart. Every change returns a new cart in one step (ARC-07).
class Cart {
  const Cart(this.lines);

  static const empty = Cart([]);

  final List<CartLine> lines;

  int get itemCount => lines.fold(0, (s, l) => s + l.qty);

  CartLine? line(String lineId) {
    for (final l in lines) {
      if (l.lineId == lineId) return l;
    }
    return null;
  }

  /// Adds [line]; the same product with exactly the same choices (size,
  /// options, ingredients, notes) only raises the existing line's quantity
  /// (owner request), so the cart never holds two identical lines.
  Cart add(CartLine line) {
    for (final l in lines) {
      if (l.selection == line.selection) {
        return setQty(l.lineId, l.qty + line.qty);
      }
    }
    return Cart([...lines, line]);
  }

  /// Replaces a line's selection in place, keeping its id and position. If
  /// the edit makes it identical to another line, the two merge into that
  /// other line.
  Cart replace(String lineId, Selection selection) {
    final edited = line(lineId);
    for (final l in lines) {
      if (l.lineId != lineId && l.selection == selection && edited != null) {
        return setQty(l.lineId, l.qty + edited.qty).remove(lineId);
      }
    }
    return Cart([
      for (final l in lines)
        l.lineId == lineId ? l.copyWith(selection: selection) : l,
    ]);
  }

  Cart setQty(String lineId, int qty) => qty < 1
      ? remove(lineId)
      : Cart([
          for (final l in lines) l.lineId == lineId ? l.copyWith(qty: qty) : l,
        ]);

  Cart remove(String lineId) => Cart([
    for (final l in lines)
      if (l.lineId != lineId) l,
  ]);

  factory Cart.fromJson(Json j) => Cart([
    for (final l in (j['lines'] as List? ?? const []))
      CartLine.fromJson(l as Json),
  ]);

  Json toJson() => {
    'version': 1,
    'lines': [for (final l in lines) l.toJson()],
  };
}
