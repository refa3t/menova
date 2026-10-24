import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

/// Kitchen ticket (P1-F06): black on white, sized for an 80mm thermal roll,
/// built only from the order's frozen data. "بدون X" lines are bold and
/// boxed so they cannot be missed. Ends with the developer credit (P1-A07).
class KitchenTicket extends StatelessWidget {
  const KitchenTicket({super.key, required this.order});

  final Order order;

  /// 80mm roll ≈ 302 logical px at 96 dpi.
  static const width = 302.0;

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(color: Colors.black, fontSize: 13, height: 1.35);
    final bold = base.copyWith(fontWeight: FontWeight.w700);
    final c = order.customer;
    final created = DateTime.tryParse(order.createdAt)?.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    Widget rule() => const Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Divider(color: Colors.black, thickness: 1, height: 1),
    );

    return Container(
      width: width,
      color: Colors.white,
      padding: const EdgeInsets.all(10),
      child: DefaultTextStyle(
        style: base,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '#${AppStrings.shortReference(order.id)}',
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
              style: bold.copyWith(fontSize: 22),
            ),
            if (created != null)
              Text(
                '${two(created.hour)}:${two(created.minute)}  '
                '${created.year}-${two(created.month)}-${two(created.day)}',
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
              ),
            Text(
              AppStrings.fulfillment(c.fulfillment),
              textAlign: TextAlign.center,
              style: bold.copyWith(fontSize: 16),
            ),
            rule(),
            for (final item in order.items) ...[
              Text(
                '${item.qty} × ${item.productName}',
                style: bold.copyWith(fontSize: 15),
              ),
              if ([
                item.sizeName,
                ...item.optionNames.values,
              ].nonNulls.isNotEmpty)
                Text(
                  [
                    item.sizeName,
                    ...item.optionNames.values,
                  ].nonNulls.join(' · '),
                ),
              for (final e in item.extras.entries)
                Text(
                  '+ ${item.ingredientNames[e.key] ?? e.key}'
                  '${e.value > 1 ? ' ×${e.value}' : ''}',
                  style: bold,
                ),
              for (final id in item.removed)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(border: Border.all(width: 1.5)),
                  child: Text(
                    '${AppStrings.without} ${item.ingredientNames[id] ?? id}',
                    style: bold.copyWith(fontSize: 15),
                  ),
                ),
              if (item.selection.notes.isNotEmpty)
                Text(
                  '${AppStrings.notes}: ${item.selection.notes}',
                  style: bold,
                ),
              const SizedBox(height: 6),
            ],
            if (order.notes.isNotEmpty) ...[
              rule(),
              Text('${AppStrings.orderNotes}: ${order.notes}', style: bold),
            ],
            rule(),
            Text('${c.name} · ${c.phone}', textDirection: TextDirection.rtl),
            if (c.address != null) Text(c.address!),
            Row(
              children: [
                Text(AppStrings.total, style: bold),
                const Spacer(),
                Text(AppStrings.price(order.total), style: bold),
              ],
            ),
            Text(AppStrings.paymentStatus(order.paymentStatus)),
            rule(),
            Text(
              AppStrings.credit,
              textAlign: TextAlign.center,
              style: base.copyWith(fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }
}
