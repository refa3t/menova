import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/strings/app_strings.dart';
import 'kitchen_ticket.dart';

/// One order by id, any status (a completed or cancelled one too, from
/// the history), live. Null while missing or unreadable.
final ticketOrderProvider = StreamProvider.autoDispose.family<Order?, String>(
  (ref, id) => FirebaseFirestore.instance
      .collection('orders')
      .doc(id)
      .snapshots()
      .map((d) {
        final data = d.data();
        if (data == null) return null;
        try {
          return Order.fromJson(data);
        } on Object {
          return null;
        }
      }),
);

/// Shows one ticket alone on a white page and opens the browser's print
/// dialog once it is laid out.
class TicketScreen extends ConsumerStatefulWidget {
  const TicketScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<TicketScreen> createState() => _TicketScreenState();
}

class _TicketScreenState extends ConsumerState<TicketScreen> {
  bool _printed = false;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(ticketOrderProvider(widget.orderId)).value;
    if (order != null && !_printed) {
      _printed = true;
      // Give images and fonts a moment, then print.
      Future<void>.delayed(
        const Duration(milliseconds: 400),
        () => web.window.print(),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(AppStrings.printTicket),
        actions: [
          TextButton(
            onPressed: order == null ? null : () => web.window.print(),
            child: const Text(AppStrings.printAgain),
          ),
        ],
      ),
      body: order == null
          ? const Center(child: Text(AppStrings.orderNotFound))
          : SingleChildScrollView(
              child: Align(
                alignment: Alignment.topCenter,
                child: KitchenTicket(order: order),
              ),
            ),
    );
  }
}
