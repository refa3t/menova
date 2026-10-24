import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/order_alerts.dart';
import 'new_order_sound.dart';
import 'order_card.dart';

/// Live active orders, newest first (P1-F02). Filtering by status happens
/// on the client so no composite index is needed.
final activeOrdersProvider = StreamProvider<List<Order>>(
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
              o,
        ],
      ),
);

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  Set<String>? _seen;
  final _highlight = <String>{};
  bool _soundOn = false;

  @override
  Widget build(BuildContext context) {
    ref.listen(activeOrdersProvider, (_, next) {
      final orders = next.value;
      if (orders == null) return;
      final fresh = newOrderIds(_seen, orders);
      _seen = {for (final o in orders) o.id};
      if (fresh.isEmpty) return;
      setState(() => _highlight.addAll(fresh));
      if (_soundOn) playNewOrderSound();
    });
    final orders = ref.watch(activeOrdersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppStrings.orders),
        actions: [
          // Browsers block sound until the user interacts (ASSETS.md 4.5).
          TextButton.icon(
            onPressed: () {
              setState(() => _soundOn = !_soundOn);
              if (_soundOn) playNewOrderSound();
            },
            icon: Icon(_soundOn ? Icons.volume_up : Icons.volume_off),
            label: Text(_soundOn ? AppStrings.soundOn : AppStrings.enableSound),
          ),
          TextButton(
            onPressed: FirebaseAuth.instance.signOut,
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.ordersLoadError)),
        data: (list) => list.isEmpty
            ? const Center(child: Text(AppStrings.noOrders))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 460,
                  mainAxisExtent: 420,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => setState(() => _highlight.remove(list[i].id)),
                  child: SingleChildScrollView(
                    child: OrderCard(
                      order: list[i],
                      highlight: _highlight.contains(list[i].id),
                    ),
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
