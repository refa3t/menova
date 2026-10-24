import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// Order confirmation and tracking (P1-E09): the reference number and the
/// order and payment statuses shown separately (CLAUDE.md 5.3).
class OrderStatusView extends StatelessWidget {
  const OrderStatusView({super.key, required this.order});

  final Order order;

  /// The normal lifecycle, in order. `cancelled` is shown on its own.
  static const _flow = [
    OrderStatus.newOrder,
    OrderStatus.accepted,
    OrderStatus.preparing,
    OrderStatus.ready,
    OrderStatus.outForDelivery,
    OrderStatus.completed,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final steps = order.customer.fulfillment == Fulfillment.pickup
        ? _flow.where((s) => s != OrderStatus.outForDelivery).toList()
        : _flow;
    final current = steps.indexOf(order.status);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(AppStrings.orderReference, style: theme.textTheme.bodyMedium),
        SelectableText(
          AppStrings.shortReference(order.id),
          textDirection: TextDirection.ltr,
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatusChip(
                label: AppStrings.orderStatusLabel,
                value: AppStrings.orderStatus(order.status),
                color: order.status == OrderStatus.cancelled
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatusChip(
                label: AppStrings.paymentStatusLabel,
                value: AppStrings.paymentStatus(order.paymentStatus),
                color: theme.colorScheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (order.status == OrderStatus.cancelled)
          Text(
            AppStrings.orderCancelled,
            style: TextStyle(color: theme.colorScheme.error),
          )
        else
          for (final (i, s) in steps.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                i <= current
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: i <= current
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              title: Text(
                AppStrings.orderStatus(s),
                style: i == current
                    ? const TextStyle(fontWeight: FontWeight.w700)
                    : null,
              ),
            ),
        const Divider(height: 32),
        Row(
          children: [
            const Text(AppStrings.subtotal),
            const Spacer(),
            Text(
              AppStrings.price(order.total),
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
