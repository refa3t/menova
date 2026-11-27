import 'order_board.dart';

/// How long an active order may wait before the board warns about it. The
/// one place these thresholds live (TEMP defaults until the owner sets them).
abstract final class OrderTiming {
  /// Yellow from here.
  static const warnAfter = Duration(minutes: 15);

  /// Red, and counted as late in the header, from here.
  static const lateAfter = Duration(minutes: 25);

  /// How often the board's single timer refreshes the clocks.
  static const tick = Duration(seconds: 15);
}

enum Urgency { onTime, warning, late }

/// Time since [placedAt], never negative (clock skew); zero when unknown.
Duration waitedFor(DateTime? placedAt, DateTime now) {
  if (placedAt == null) return Duration.zero;
  final d = now.difference(placedAt);
  return d.isNegative ? Duration.zero : d;
}

Urgency urgencyOf(Duration waited) => waited >= OrderTiming.lateAfter
    ? Urgency.late
    : waited >= OrderTiming.warnAfter
    ? Urgency.warning
    : Urgency.onTime;

/// Active orders waiting past [OrderTiming.lateAfter].
int lateCount(Iterable<BoardOrder> orders, DateTime now) => orders
    .where((o) => urgencyOf(waitedFor(o.placedAt, now)) == Urgency.late)
    .length;
