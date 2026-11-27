import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../orders/presentation/order_card.dart';
import '../data/day_orders_provider.dart';
import '../domain/order_history.dart';

/// Orders of one day (today by default) in every status, newest first,
/// with a summary of the day and a search by reference, name or phone.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  DateTime _day = dayRange(DateTime.now()).from;
  final _search = TextEditingController();

  bool get _isToday => _day == dayRange(DateTime.now()).from;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pickDay() async {
    final today = dayRange(DateTime.now()).from;
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
      helpText: AppStrings.pickDay,
    );
    if (picked != null) setState(() => _day = dayRange(picked).from);
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(dayOrdersProvider(_day));
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.history),
        actions: [
          if (!_isToday)
            TextButton(
              onPressed: () =>
                  setState(() => _day = dayRange(DateTime.now()).from),
              child: const Text(AppStrings.today),
            ),
          TextButton.icon(
            onPressed: _pickDay,
            icon: const Icon(Icons.calendar_today_outlined),
            label: Text(AppStrings.day(_day), textDirection: TextDirection.ltr),
          ),
          TextButton.icon(
            onPressed: () => context.go('/'),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text(AppStrings.backToOrders),
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.ordersLoadError)),
        data: (list) {
          final shown = filterOrders(list, _search.text);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryPanel(
                title: AppStrings.summaryOf(_day, isToday: _isToday),
                summary: summarize([for (final d in list) d.order]),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: AppStrings.historySearch,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: AppStrings.clearSearch,
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (list.isEmpty)
                const _Empty(AppStrings.noOrdersOnDay)
              else if (shown.isEmpty)
                const _Empty(AppStrings.noMatches)
              else
                for (final d in shown) _OrderRow(entry: d),
            ],
          );
        },
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(AppStrings.credit, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Text(text, textAlign: TextAlign.center),
  );
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({required this.title, required this.summary});

  final String title;
  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _Stat(AppStrings.ordersCount, '${summary.count}'),
                _Stat(
                  AppStrings.sales,
                  AppStrings.price(summary.sales),
                  note: AppStrings.salesNote,
                ),
                _Stat(AppStrings.cashCollected, AppStrings.price(summary.cash)),
                _Stat(
                  AppStrings.fulfillment(Fulfillment.delivery),
                  '${summary.delivery}',
                ),
                _Stat(
                  AppStrings.fulfillment(Fulfillment.pickup),
                  '${summary.pickup}',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in summary.byStatus.entries)
                  Chip(
                    label: Text(
                      AppStrings.countOf(
                        AppStrings.orderStatus(e.key),
                        e.value,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, {this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(value, style: theme.textTheme.titleLarge),
          if (note case final n?) Text(n, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.entry});

  final DayOrder entry;

  @override
  Widget build(BuildContext context) {
    final o = entry.order;
    return Card(
      child: ListTile(
        minTileHeight: 56,
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _OrderDetail(order: o),
        ),
        leading: Text(
          AppStrings.time(entry.at),
          textDirection: TextDirection.ltr,
        ),
        title: Text('#${AppStrings.shortReference(o.id)} · ${o.customer.name}'),
        subtitle: Text(
          '${o.customer.phone} · ${AppStrings.fulfillment(o.customer.fulfillment)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppStrings.price(orderAmount(o))),
            Text(
              '${AppStrings.orderStatus(o.status)} · '
              '${AppStrings.paymentStatus(o.paymentStatus)}',
            ),
          ],
        ),
      ),
    );
  }
}

/// The order's full detail, read-only, with printing its ticket.
class _OrderDetail extends StatelessWidget {
  const _OrderDetail({required this.order});

  final Order order;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(child: OrderCard(order: order)),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  FilledButton.icon(
                    onPressed: () {
                      final router = GoRouter.of(context);
                      Navigator.of(context).pop();
                      router.push('/ticket/${order.id}');
                    },
                    icon: const Icon(Icons.print_outlined),
                    label: const Text(AppStrings.print),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(AppStrings.close),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
