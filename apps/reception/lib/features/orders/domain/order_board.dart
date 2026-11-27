import 'package:core/core.dart';

/// An active order with the time the server recorded it
/// (`serverCreatedAt`), which the board's timers count from.
class BoardOrder {
  const BoardOrder(this.order, {this.placedAt});

  final Order order;

  /// Server time of creation; falls back to the order's own `createdAt`
  /// while the server timestamp is pending or missing. Null if neither
  /// parses.
  final DateTime? placedAt;

  String get id => order.id;

  /// [serverCreatedAt] is the decoded server timestamp, if any.
  factory BoardOrder.of(Order order, {DateTime? serverCreatedAt}) => BoardOrder(
    order,
    placedAt: serverCreatedAt ?? DateTime.tryParse(order.createdAt),
  );
}

/// The board's columns, left to right in the order staff work them.
enum BoardColumn {
  incoming({OrderStatus.newOrder}),
  kitchen({OrderStatus.accepted, OrderStatus.preparing}),
  ready({OrderStatus.ready}),
  onTheWay({OrderStatus.outForDelivery});

  const BoardColumn(this.statuses);

  final Set<OrderStatus> statuses;

  /// The column showing [status]; null for finished orders, which leave the
  /// board.
  static BoardColumn? of(OrderStatus status) {
    for (final c in values) {
      if (c.statuses.contains(status)) return c;
    }
    return null;
  }
}

/// Orders per column, every column present, oldest first so the order
/// waiting longest is on top. Orders without a time go last.
Map<BoardColumn, List<BoardOrder>> groupByColumn(Iterable<BoardOrder> orders) {
  final board = {for (final c in BoardColumn.values) c: <BoardOrder>[]};
  for (final o in orders) {
    if (BoardColumn.of(o.order.status) case final c?) board[c]!.add(o);
  }
  for (final list in board.values) {
    list.sort((a, b) {
      final x = a.placedAt, y = b.placedAt;
      if (x == null || y == null) return x == null ? (y == null ? 0 : 1) : -1;
      return x.compareTo(y);
    });
  }
  return board;
}
