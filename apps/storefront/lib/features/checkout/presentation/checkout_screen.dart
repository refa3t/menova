import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../cart/domain/cart_line_view.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../menu/presentation/menu_providers.dart';
import '../domain/guest_form.dart';

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

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    _saveGuest();
    // Sending goes through createOrder (P1-E05), blocked by D-INFRA-01.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text(AppStrings.orderingUnavailable)),
      );
  }

  @override
  Widget build(BuildContext context) {
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
      appBar: AppBar(title: const Text(AppStrings.checkout)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              decoration: const InputDecoration(labelText: AppStrings.name),
              validator: (v) => message(GuestValidation.name(v ?? '')),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              autofillHints: const [AutofillHints.telephoneNumber],
              decoration: const InputDecoration(labelText: AppStrings.phone),
              validator: (v) => message(GuestValidation.phone(v ?? '')),
            ),
            const SizedBox(height: 16),
            Text(
              AppStrings.fulfillment,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            // TEMP: both methods offered until OWNER_INPUTS decision 4.
            SegmentedButton<Fulfillment>(
              segments: const [
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
                decoration: const InputDecoration(
                  labelText: AppStrings.address,
                ),
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
              decoration: const InputDecoration(
                labelText: AppStrings.orderNotes,
              ),
            ),
            const SizedBox(height: 8),
            if (subtotal != null)
              Row(
                children: [
                  const Text(AppStrings.subtotal),
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
          child: FilledButton(
            onPressed: cart.lines.isEmpty ? null : _confirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text(AppStrings.confirmOrder),
          ),
        ),
      ),
    );
  }
}
