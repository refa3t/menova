import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../cart/domain/cart_line_view.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../menu/presentation/menu_providers.dart';
import '../domain/guest_form.dart';
import '../domain/order_builder.dart';
import 'checkout_controller.dart';

/// Guest checkout (P1-E04). The guest's details are kept on their device.
class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  static const _guestKey = 'guest.v1';

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  Fulfillment _fulfillment = Fulfillment.pickup;

  @override
  void initState() {
    super.initState();
    final raw = ref.read(sharedPreferencesProvider).getString(_guestKey);
    if (raw == null) return;
    try {
      final g = GuestCustomer.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      _name.text = g.name;
      _phone.text = g.phone;
      _address.text = g.address ?? '';
      _fulfillment = g.fulfillment;
    } on Object {
      // Ignore a corrupt saved guest.
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  void _saveGuest() {
    final g = GuestCustomer(
      name: _name.text.trim(),
      phone: GuestValidation.normalizePhone(_phone.text),
      fulfillment: _fulfillment,
      address: _fulfillment == Fulfillment.delivery
          ? _address.text.trim()
          : null,
    );
    ref
        .read(sharedPreferencesProvider)
        .setString(_guestKey, jsonEncode(g.toJson()));
  }

  GuestCustomer _customer() => GuestCustomer(
    name: _name.text.trim(),
    phone: GuestValidation.normalizePhone(_phone.text),
    fulfillment: _fulfillment,
    address: _fulfillment == Fulfillment.delivery ? _address.text.trim() : null,
  );

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    _saveGuest();
    ref
        .read(checkoutProvider.notifier)
        .confirm(customer: _customer(), notes: _notes.text.trim());
  }

  void _onState(CheckoutState? _, CheckoutState next) {
    switch (next) {
      case CheckoutDone(:final orderId):
        context.go('/order/$orderId');
      case CheckoutPriceChanged(:final diffs):
        _showDiffs(diffs);
      case CheckoutConflict():
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(AppStrings.orderConflict)));
        ref.read(checkoutProvider.notifier).dismiss();
      default:
        break;
    }
  }

  Future<void> _showDiffs(List<PriceDiff> diffs) async {
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.pricesChanged),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.pricesChangedBody),
            const SizedBox(height: 12),
            for (final d in diffs)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  d.current == null
                      ? '${d.productName}: ${AppStrings.noLongerAvailable}'
                      : '${d.productName}: '
                            '${d.shown == null ? '—' : AppStrings.price(d.shown!)}'
                            ' ← ${AppStrings.price(d.current!)}',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.backToCart),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.acceptNewPrices),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final controller = ref.read(checkoutProvider.notifier);
    if (accepted == true) {
      controller.acceptCorrections();
    } else {
      controller.dismiss();
      if (mounted) context.go('/cart');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(checkoutProvider, _onState);
    final checkout = ref.watch(checkoutProvider);
    final sending = checkout is CheckoutSending;
    final cart = ref.watch(cartProvider);
    final menu = ref.watch(menuProvider).value;
    final subtotal = menu == null
        ? null
        : cart.lines.fold<int>(0, (s, l) {
            final v = CartLineView.resolve(l, menu);
            return s + (v.price?.total ?? 0);
          });
    String? message(String? key) => switch (key) {
      'name' => AppStrings.errorName,
      'phone' => AppStrings.errorPhone,
      'address' => AppStrings.errorAddress,
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.checkout)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: InputDecoration(labelText: AppStrings.name),
              validator: (v) => message(GuestValidation.name(v ?? '')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: InputDecoration(labelText: AppStrings.phone),
              validator: (v) => message(GuestValidation.phone(v ?? '')),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.fulfillment,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 8),
            // TEMP: both methods offered until OWNER_INPUTS decision 4.
            SegmentedButton<Fulfillment>(
              segments: [
                ButtonSegment(
                  value: Fulfillment.pickup,
                  label: Text(AppStrings.pickup),
                ),
                ButtonSegment(
                  value: Fulfillment.delivery,
                  label: Text(AppStrings.delivery),
                ),
              ],
              selected: {_fulfillment},
              onSelectionChanged: (s) => setState(() => _fulfillment = s.first),
            ),
            if (_fulfillment == Fulfillment.delivery) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                minLines: 2,
                maxLines: 4,
                autofillHints: const [AutofillHints.fullStreetAddress],
                decoration: InputDecoration(labelText: AppStrings.address),
                validator: (v) =>
                    message(GuestValidation.address(v ?? '', _fulfillment)),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLength: 300,
              minLines: 1,
              maxLines: 3,
              decoration: InputDecoration(labelText: AppStrings.orderNotes),
            ),
            const SizedBox(height: 8),
            if (subtotal != null)
              Row(
                children: [
                  Text(AppStrings.subtotal),
                  const Spacer(),
                  Text(
                    AppStrings.price(subtotal),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              AppStrings.paymentCash,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (checkout is CheckoutPending)
                Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                    AppStrings.pendingSend,
                    textAlign: TextAlign.center,
                  ),
                ),
              FilledButton(
                onPressed: cart.lines.isEmpty || sending ? null : _confirm,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: Text(switch (checkout) {
                  CheckoutSending(checking: true) => AppStrings.checkingOrder,
                  CheckoutSending() => AppStrings.sendingOrder,
                  CheckoutPending() => AppStrings.retrySend,
                  _ => AppStrings.confirmOrder,
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
