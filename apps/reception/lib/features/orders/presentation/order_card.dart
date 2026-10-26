import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/delivery_check.dart';
import '../domain/order_verification.dart';

/// Kitchen order card (P1-F03, FR-OR-03): size and options, kept defaults,
/// added extras, and removed defaults as "بدون X" in a distinct colour, plus
/// notes and pickup or delivery details. Reads only frozen order data.
class OrderCard extends StatelessWidget {
  const OrderCard({
    super.key,
    required this.order,
    this.highlight = false,
    this.verification,
    this.deliveryCheck,
    this.actions,
  });

  /// Re-measured delivery distance and fee; null for pickup or while it
  /// loads.
  final DeliveryCheck? deliveryCheck;

  /// Re-pricing result (amended SEC-02); null while prices load.
  final OrderVerification? verification;

  /// Status and payment actions (P1-F04, P1-F05).
  final Widget? actions;

  final Order order;

  /// True for a newly arrived order.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = order.customer;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side:
            verification?.matches == false ||
                deliveryCheck?.result == DeliveryCheckResult.mismatch
            ? BorderSide(color: theme.colorScheme.error, width: 3)
            : highlight
            ? BorderSide(color: theme.colorScheme.primary, width: 3)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '#${AppStrings.shortReference(order.id)}',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.titleLarge,
                ),
                const Spacer(),
                _Chip(AppStrings.orderStatus(order.status)),
                const SizedBox(width: 6),
                _Chip(AppStrings.paymentStatus(order.paymentStatus)),
                IconButton(
                  tooltip: AppStrings.print,
                  onPressed: () => context.push('/ticket/${order.id}'),
                  icon: const Icon(Icons.print_outlined),
                ),
              ],
            ),
            if (verification case final v? when !v.matches)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: theme.colorScheme.errorContainer,
                child: Text(
                  v.computedTotal == null
                      ? AppStrings.priceUnverifiable
                      : AppStrings.priceMismatch(v.computedTotal!),
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (deliveryCheck case final d?
                when d.result == DeliveryCheckResult.mismatch)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                color: theme.colorScheme.errorContainer,
                child: Text(
                  AppStrings.deliveryMismatch(d.expectedFee, d.roadMeters!),
                  style: TextStyle(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (deliveryCheck?.result == DeliveryCheckResult.unverified)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppStrings.deliveryUnverified,
                  style: theme.textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              '${AppStrings.fulfillment(c.fulfillment)} · ${c.name} · ${c.phone}',
            ),
            if (c.address != null) Text(c.address!),
            if (c.distanceMeters != null)
              Text(AppStrings.distance(c.distanceMeters!)),
            if (c.location case final at?)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => launchUrl(
                    Uri.parse(
                      'https://www.google.com/maps/search/?api=1&query=${at.lat},${at.lng}',
                    ),
                    webOnlyWindowName: '_blank',
                  ),
                  icon: const Icon(Icons.map_outlined),
                  label: const Text(AppStrings.openMap),
                ),
              ),
            const Divider(height: 24),
            for (final item in order.items) _Item(item: item),
            if (order.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '${AppStrings.orderNotes}: ${order.notes}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            const Divider(height: 24),
            if (order.deliveryFee > 0) ...[
              _Amount(AppStrings.subtotal, order.total - order.deliveryFee),
              _Amount(AppStrings.deliveryFee, order.deliveryFee),
            ],
            Row(
              children: [
                const Text(AppStrings.total),
                const Spacer(),
                Text(
                  AppStrings.price(order.total),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (actions != null) ...[const Divider(height: 24), actions!],
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item});

  final OrderItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    String name(String id) => item.ingredientNames[id] ?? id;
    final details = [
      if (item.sizeName != null) item.sizeName!,
      ...item.optionNames.values,
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.qty} × ${item.productName}',
            style: theme.textTheme.titleMedium,
          ),
          if (details.isNotEmpty) Text(details),
          if (item.kept.isNotEmpty)
            Text(
              '${AppStrings.includes}: ${item.kept.keys.map(name).join('، ')}',
              style: theme.textTheme.bodySmall,
            ),
          for (final e in item.extras.entries)
            Text(
              e.value > 1 ? '+ ${name(e.key)} ×${e.value}' : '+ ${name(e.key)}',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          for (final id in item.removed)
            Container(
              margin: const EdgeInsets.only(top: 2),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              color: theme.colorScheme.errorContainer,
              child: Text(
                '${AppStrings.without} ${name(id)}',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (item.selection.notes.isNotEmpty)
            Text(
              '${AppStrings.notes}: ${item.selection.notes}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.amount);

  final String label;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Text(label), const Spacer(), Text(AppStrings.price(amount))],
    );
  }
}
