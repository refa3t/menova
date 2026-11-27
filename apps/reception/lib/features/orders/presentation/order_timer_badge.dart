import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/order_board.dart';
import '../domain/order_timing.dart';

/// Badge colours per urgency: neutral, yellow, red.
({Color background, Color foreground}) urgencyColors(
  ColorScheme scheme,
  Urgency urgency,
) => switch (urgency) {
  Urgency.onTime => (
    background: scheme.surfaceContainerHighest,
    foreground: scheme.onSurfaceVariant,
  ),
  Urgency.warning => (
    background: Colors.amber.shade300,
    foreground: Colors.black87,
  ),
  Urgency.late => (background: scheme.error, foreground: scheme.onError),
};

/// Minutes since the order was placed, ticking with the board's clock and
/// coloured by [urgencyOf]. An icon marks warning and late, so colour is not
/// the only signal.
class OrderTimerBadge extends StatelessWidget {
  const OrderTimerBadge({super.key, required this.placedAt, required this.now});

  final DateTime? placedAt;
  final ValueListenable<DateTime> now;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: now,
      builder: (context, at, _) {
        final waited = waitedFor(placedAt, at);
        final urgency = urgencyOf(waited);
        final colors = urgencyColors(Theme.of(context).colorScheme, urgency);
        return Tooltip(
          message: switch (urgency) {
            Urgency.onTime => AppStrings.waitOnTime,
            Urgency.warning => AppStrings.waitWarning,
            Urgency.late => AppStrings.waitLate,
          },
          child: Container(
            key: ValueKey('timer-${urgency.name}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colors.background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  urgency == Urgency.onTime
                      ? Icons.schedule
                      : Icons.warning_amber_rounded,
                  size: 16,
                  color: colors.foreground,
                ),
                const SizedBox(width: 4),
                Text(
                  AppStrings.minutesWaited(waited.inMinutes),
                  style: TextStyle(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Header count of orders past [OrderTiming.lateAfter]; hidden when none.
class LateCount extends StatelessWidget {
  const LateCount({super.key, required this.orders, required this.now});

  final List<BoardOrder> orders;
  final ValueListenable<DateTime> now;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: now,
      builder: (context, at, _) {
        final n = lateCount(orders, at);
        if (n == 0) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        return Tooltip(
          message: AppStrings.lateOrdersHint,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.error,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm, size: 18, color: scheme.onError),
                const SizedBox(width: 4),
                Text(
                  AppStrings.lateOrders(n),
                  style: TextStyle(
                    color: scheme.onError,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
