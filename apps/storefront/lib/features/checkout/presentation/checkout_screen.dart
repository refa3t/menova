import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../cart/domain/cart_line_view.dart';
import '../../cart/presentation/cart_providers.dart';
import '../../delivery/domain/delivery_quote.dart';
import '../../delivery/presentation/delivery_controller.dart';
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

  GuestCustomer _customer(DeliveryQuote? quote) => GuestCustomer(
    name: _name.text.trim(),
    phone: GuestValidation.normalizePhone(_phone.text),
    fulfillment: _fulfillment,
    address: _fulfillment == Fulfillment.delivery ? _address.text.trim() : null,
    location: quote?.location,
    distanceMeters: quote?.distanceMeters,
  );

  /// The priced delivery, when one is priced.
  DeliveryQuote? _quote() => switch (ref.read(deliveryProvider)) {
    DeliveryQuoted(:final quote) => quote,
    _ => null,
  };

  void _confirm() {
    if (!_form.currentState!.validate()) return;
    final quote = _fulfillment == Fulfillment.delivery ? _quote() : null;
    if (_fulfillment == Fulfillment.delivery && quote == null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppStrings.deliveryNeedsLocation)),
        );
      return;
    }
    _saveGuest();
    ref
        .read(checkoutProvider.notifier)
        .confirm(
          customer: _customer(quote),
          notes: _notes.text.trim(),
          shownDeliveryFee: quote?.fee ?? 0,
        );
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
                      ? '${_diffName(d)}: ${_isDelivery(d) ? AppStrings.outOfRange : AppStrings.noLongerAvailable}'
                      : '${_diffName(d)}: '
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

  bool _isDelivery(PriceDiff d) =>
      d.lineId == CheckoutController.deliveryLineId;

  String _diffName(PriceDiff d) =>
      _isDelivery(d) ? AppStrings.deliveryFee : d.productName;

  @override
  Widget build(BuildContext context) {
    ref.listen(checkoutProvider, _onState);
    final delivery = ref.watch(deliveryProvider);
    final int? fee = _fulfillment == Fulfillment.delivery
        ? switch (delivery) {
            DeliveryQuoted(:final quote) => quote.fee,
            _ => null,
          }
        : 0;
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
            // Pickup and delivery (owner decision, OWNER_INPUTS 4).
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
              const SizedBox(height: 12),
              _DeliveryLocation(state: delivery),
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
            if (subtotal != null) ...[
              _TotalRow(AppStrings.subtotal, subtotal),
              if (_fulfillment == Fulfillment.delivery)
                _TotalRow(AppStrings.deliveryFee, fee),
              _TotalRow(
                AppStrings.orderTotal,
                fee == null ? null : subtotal + fee,
                strong: true,
              ),
            ],
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

class _TotalRow extends StatelessWidget {
  const _TotalRow(this.label, this.amount, {this.strong = false});

  final String label;
  final int? amount;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(amount == null ? '—' : AppStrings.price(amount!), style: style),
        ],
      ),
    );
  }
}

/// Delivery pricing from the guest's location: a button, then the road
/// distance and fee, or why it could not be priced.
class _DeliveryLocation extends ConsumerWidget {
  const _DeliveryLocation({required this.state});

  final DeliveryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(deliveryProvider.notifier);
    final theme = Theme.of(context);
    final (String? info, bool error) = switch (state) {
      DeliveryQuoted(:final quote) => (
        '${AppStrings.deliveryDistance(quote.distanceMeters)} · '
            '${AppStrings.deliveryFee}: ${AppStrings.price(quote.fee)}',
        false,
      ),
      DeliveryFailed(:final error) => (
        switch (error) {
          DeliveryError.denied => AppStrings.locationDenied,
          DeliveryError.unavailable => AppStrings.locationUnavailable,
          DeliveryError.routeFailed => AppStrings.routeFailed,
          DeliveryError.outOfRange => AppStrings.outOfRange,
        },
        true,
      ),
      _ => (null, false),
    };
    final locating = state is DeliveryLocating;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: locating ? null : controller.locate,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: locating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.my_location),
          label: Text(
            locating
                ? AppStrings.locating
                : state is DeliveryQuoted
                ? AppStrings.relocate
                : AppStrings.useMyLocation,
          ),
        ),
        if (info != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              info,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: error ? theme.colorScheme.error : null,
              ),
            ),
          ),
      ],
    );
  }
}
