import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/strings/app_strings.dart';
import 'kitchen_ticket.dart';
import 'orders_screen.dart';

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
    final orders = ref.watch(activeOrdersProvider).value ?? const [];
    final order = orders.where((o) => o.id == widget.orderId).firstOrNull;
    if (order != null && !_printed) {
      _printed = true;
      // Give images and fonts a moment, then print.
      Future<void>.delayed(const Duration(milliseconds: 400), web.window.print);
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(AppStrings.printTicket),
        actions: [
          TextButton(
            onPressed: order == null ? null : web.window.print,
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
