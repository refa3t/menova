import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';

/// The owner's store settings (P3-05): where deliveries start and how they
/// are priced. The order rules price every new delivery from this document.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _lat = TextEditingController();
  final _lng = TextEditingController();
  final _perKm = TextEditingController();
  final _minFee = TextEditingController();
  final _maxKm = TextEditingController();
  StoreSettings? _original;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_lat, _lng, _perKm, _minFee, _maxKm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(StoreSettings s) {
    if (_original != null) return;
    _original = s;
    _lat.text = '${s.location.lat}';
    _lng.text = '${s.location.lng}';
    _perKm.text = AppStrings.egp(s.delivery.perKm);
    _minFee.text = AppStrings.egp(s.delivery.minFee);
    _maxKm.text = '${s.delivery.maxDistanceMeters / 1000}';
  }

  Future<void> _save() async {
    final who = ref.read(adminAccessProvider).value;
    final original = _original;
    if (who is! Granted || original == null || _saving) return;
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    final perKm = AppStrings.parseEgp(_perKm.text);
    final minFee = AppStrings.parseEgp(_minFee.text);
    final maxKm = double.tryParse(_maxKm.text.trim());
    if (lat == null ||
        lng == null ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        perKm == null ||
        minFee == null ||
        maxKm == null ||
        maxKm <= 0) {
      setState(() => _error = AppStrings.invalidNumber);
      return;
    }
    final after = StoreSettings(
      location: LatLng(lat, lng),
      delivery: DeliverySettings(
        perKm: perKm,
        minFee: minFee,
        maxDistanceMeters: (maxKm * 1000).round(),
      ),
    );
    setState(() {
      _error = null;
      _saving = true;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'saveStoreSettings',
            path: 'settings/store',
            before: original.toJson(),
            after: after.toJson(),
          );
      _original = after;
      messenger.showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.saveFailed)),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storeSettingsProvider).value;
    if (settings == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _load(settings);
    Widget field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        textDirection: TextDirection.ltr,
        decoration: InputDecoration(labelText: label),
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                AppStrings.storeLocation,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              field(_lat, AppStrings.lat),
              field(_lng, AppStrings.lng),
              SelectableText(
                'https://www.google.com/maps/search/?api=1&query='
                '${_lat.text},${_lng.text}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.deliveryNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              field(_perKm, AppStrings.perKm),
              field(_minFee, AppStrings.minFee),
              field(_maxKm, AppStrings.maxKm),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? AppStrings.saving : AppStrings.save),
          ),
        ),
      ),
    );
  }
}
