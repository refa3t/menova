import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseFirestore, Timestamp;
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../data/delivery_check_provider.dart';
import '../data/pricing_data_provider.dart';
import '../domain/order_alerts.dart';
import '../domain/order_board.dart';
import '../domain/order_verification.dart';
import 'board_clock.dart';
import 'new_order_sound.dart';
import 'order_action_bar.dart';
import 'order_card.dart';
import 'order_timer_badge.dart';
import 'orders_board.dart';

/// Live active orders with their server creation time (P1-F02). Filtering
/// by status happens on the client so no composite index is needed.
final boardOrdersProvider = StreamProvider<List<BoardOrder>>(
  (ref) => FirebaseFirestore.instance
      .collection('orders')
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(
        (s) => [
          for (final d in s.docs)
            if (Order.fromJson(d.data()) case final o
                when activeStatuses.contains(o.status))
              BoardOrder.of(
                o,
                serverCreatedAt: switch (d.data()['serverCreatedAt']) {
                  final Timestamp t => t.toDate(),
                  _ => null,
                },
              ),
        ],
      ),
);

/// The active orders alone, newest first (used by the ticket screen).
final activeOrdersProvider = Provider<AsyncValue<List<Order>>>(
  (ref) => ref
      .watch(boardOrdersProvider)
      .whenData((list) => [for (final b in list) b.order]),
);

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Set<String>? _seen;
  final _highlight = <String>{};
  final _expanded = <String>{};
  bool _soundOn = false;
  final _sound = NewOrderSound.browser();
  late final BoardClock _clock = BoardClock(now: ref.read(boardNowProvider));

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  void _tapped(String id) => setState(() {
    _highlight.remove(id);
    if (!_expanded.remove(id)) _expanded.add(id);
  });

  @override
  Widget build(BuildContext context) {
    ref.listen(boardOrdersProvider, (_, next) {
      final orders = next.value;
      if (orders == null) return;
      final fresh = newOrderIds(_seen, [for (final b in orders) b.order]);
      _seen = {for (final b in orders) b.id};
      if (fresh.isEmpty) return;
      setState(() => _highlight.addAll(fresh));
      if (_soundOn) _sound.play();
    });
    final orders = ref.watch(boardOrdersProvider);
    final pricing = ref.watch(pricingDataProvider);
    final narrow = MediaQuery.sizeOf(context).width < boardTabsBelow;

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orders),
        actions: [
          if (orders.value case final list?)
            LateCount(orders: list, now: _clock),
          _HeaderAction(
            narrow: narrow,
            icon: Icons.history,
            label: AppStrings.history,
            onPressed: () => context.push('/history'),
          ),
          // Browsers block sound until the user interacts (ASSETS.md 4.5).
          _HeaderAction(
            narrow: narrow,
            icon: _soundOn ? Icons.volume_up : Icons.volume_off,
            label: _soundOn ? AppStrings.soundOn : AppStrings.enableSound,
            onPressed: () {
              setState(() => _soundOn = !_soundOn);
              if (_soundOn) _sound.enable();
            },
          ),
          _HeaderAction(
            narrow: narrow,
            icon: Icons.logout,
            label: AppStrings.signOut,
            onPressed: FirebaseAuth.instance.signOut,
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.ordersLoadError)),
        data: (list) => list.isEmpty
            ? const Center(child: Text(AppStrings.noOrders))
            : OrdersBoard(
                orders: list,
                cardBuilder: (context, b) => GestureDetector(
                  onTap: () => _tapped(b.id),
                  child: OrderCard(
                    order: b.order,
                    highlight: _highlight.contains(b.id),
                    expanded: _expanded.contains(b.id),
                    onToggleExpanded: () => _tapped(b.id),
                    timer: OrderTimerBadge(placedAt: b.placedAt, now: _clock),
                    verification: pricing == null
                        ? null
                        : verifyOrder(b.order, pricing),
                    deliveryCheck: switch (deliveryCheckKey(b.order)) {
                      final key? => ref.watch(deliveryCheckProvider(key)).value,
                      null => null,
                    },
                    actions: OrderActionBar(order: b.order),
                  ),
                ),
              ),
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

/// A header button: icon with tooltip on a phone, icon and label otherwise.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.narrow,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final bool narrow;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => narrow
      ? IconButton(tooltip: label, onPressed: onPressed, icon: Icon(icon))
      : TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
          icon: Icon(icon),
          label: Text(label),
        );
}
