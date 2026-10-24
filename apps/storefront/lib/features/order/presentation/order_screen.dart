import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import 'order_status_view.dart';

/// Live order document. Readable only by its guest (rules: `customerUid`),
/// which needs Anonymous Auth once ordering is enabled (P1-E05).
final orderProvider = StreamProvider.autoDispose.family<Order?, String>(
  (ref, id) => FirebaseFirestore.instance
      .doc('orders/$id')
      .snapshots()
      .map((s) => s.exists ? Order.fromJson(s.data()!) : null),
);

class OrderScreen extends ConsumerWidget {
  const OrderScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(orderProvider(orderId));
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.orderTitle)),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.orderLoadError)),
        data: (o) => o == null
            ? const Center(child: Text(AppStrings.orderNotFound))
            : OrderStatusView(order: o),
      ),
    );
  }
}
