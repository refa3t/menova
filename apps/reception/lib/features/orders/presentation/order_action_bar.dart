import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';
import '../data/order_actions.dart';
import '../domain/order_transitions.dart';

/// Buttons for the next allowed status and for payment (P1-F04, P1-F05).
class OrderActionBar extends StatefulWidget {
  const OrderActionBar({super.key, required this.order, this.actions});

  final Order order;

  /// Injectable for tests; defaults to Firestore.
  final OrderActions? actions;

  @override
  State<OrderActionBar> createState() => _OrderActionBarState();
}

class _OrderActionBarState extends State<OrderActionBar> {
  bool _busy = false;

  OrderActions get _actions =>
      widget.actions ??
      OrderActions(FirebaseFirestore.instance, FirebaseAuth.instance);

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.actionFailed)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _status(OrderStatus to) async {
    String? reason;
    if (to == OrderStatus.cancelled) {
      reason = await _askReason();
      if (reason == null) return;
    }
    await _run(() => _actions.setStatus(widget.order, to, reason: reason));
  }

  Future<String?> _askReason() {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(AppStrings.cancelOrder),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: AppStrings.cancelReason),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.back),
          ),
          FilledButton(
            onPressed: () {
              final r = controller.text.trim();
              if (r.length >= 2) Navigator.pop(context, r);
            },
            child: const Text(AppStrings.confirmCancel),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final next = nextStatuses(order);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final s in next)
          s == OrderStatus.cancelled
              ? OutlinedButton(
                  onPressed: _busy ? null : () => _status(s),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(44, 44),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: Text(AppStrings.actionFor(s)),
                )
              : FilledButton(
                  onPressed: _busy ? null : () => _status(s),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(44, 44),
                  ),
                  child: Text(AppStrings.actionFor(s)),
                ),
        for (final p in nextPaymentStatuses(order.paymentStatus))
          TextButton(
            onPressed: _busy
                ? null
                : () => _run(() => _actions.setPayment(order, p)),
            style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
            child: Text(AppStrings.markPayment(p)),
          ),
      ],
    );
  }
}
