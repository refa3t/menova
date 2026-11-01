import 'package:category_definitions/category_definitions.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore;
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/data/audited_writer.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/offers_providers.dart';

/// Creates or edits an automatic offer or a coupon (P3-09), checked like
/// the Firestore rules before an audited save. A coupon's code is set once
/// (it is its id) and its use count is never edited here.
class OfferEditScreen extends ConsumerStatefulWidget {
  const OfferEditScreen({super.key, required this.list, this.id});

  final OfferList list;

  /// Null for a new one.
  final String? id;

  @override
  ConsumerState<OfferEditScreen> createState() => _OfferEditScreenState();
}

class _OfferEditScreenState extends ConsumerState<OfferEditScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _value = TextEditingController();
  final _minOrder = TextEditingController();
  final _maxDiscount = TextEditingController();
  final _code = TextEditingController();
  final _maxUses = TextEditingController();
  var _kind = OfferKind.percent;
  String? _categoryId;
  DateTime? _start;

  /// The last day it runs (inclusive).
  DateTime? _end;
  var _active = true;
  Offer? _original;
  var _loaded = false;
  var _saving = false;
  List<String> _issues = const [];

  bool get _coupon => widget.list == OfferList.coupons;

  @override
  void dispose() {
    for (final c in [
      _nameAr,
      _nameEn,
      _value,
      _minOrder,
      _maxDiscount,
      _code,
      _maxUses,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(Offer? o) {
    if (_loaded) return;
    _loaded = true;
    if (o == null) return;
    _original = o;
    _nameAr.text = o.names['ar'] ?? o.name;
    _nameEn.text = o.names['en'] ?? '';
    _kind = o.kind;
    _value.text = switch (o.kind) {
      OfferKind.percent => '${o.value}',
      OfferKind.amount => AppStrings.egp(o.value),
      OfferKind.freeDelivery => '',
    };
    _categoryId = o.categoryId;
    _minOrder.text = o.minSubtotal == 0 ? '' : AppStrings.egp(o.minSubtotal);
    _maxDiscount.text = o.maxDiscount == null
        ? ''
        : AppStrings.egp(o.maxDiscount!);
    if (o.startsAtMs case final s?) {
      _start = DateTime.fromMillisecondsSinceEpoch(s);
    }
    if (o.endsAtMs case final e?) {
      // Stored as the start of the day after the last one.
      final after = DateTime.fromMillisecondsSinceEpoch(e);
      _end = DateTime(after.year, after.month, after.day - 1);
    }
    _active = o.isActive;
    _code.text = o.code ?? '';
    _maxUses.text = o.maxUses == null ? '' : '${o.maxUses}';
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (start ? _start : _end) ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => start ? _start = picked : _end = picked);
  }

  Future<void> _save(List<Offer> existing) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted || _saving) return;
    final original = _original;
    final issues = <String>[];
    int? money(TextEditingController c, String label) {
      if (c.text.trim().isEmpty) return null;
      final v = AppStrings.parseEgp(c.text);
      if (v == null) issues.add('$label: ${AppStrings.invalidMoney}');
      return v;
    }

    final value = switch (_kind) {
      OfferKind.percent => AppStrings.parseCount(_value.text),
      OfferKind.amount => AppStrings.parseEgp(_value.text),
      OfferKind.freeDelivery => 0,
    };
    if (value == null) issues.add(AppStrings.issue('value'));
    final minOrder = money(_minOrder, AppStrings.minOrder) ?? 0;
    final maxDiscount = _kind == OfferKind.amount
        ? null
        : money(_maxDiscount, AppStrings.maxDiscountField);
    final maxUses = _maxUses.text.trim().isEmpty
        ? null
        : AppStrings.parseCount(_maxUses.text);
    if (_coupon && _maxUses.text.trim().isNotEmpty && maxUses == null) {
      issues.add(AppStrings.issue('maxUses'));
    }
    final code = _coupon ? (original?.code ?? couponCode(_code.text)) : null;
    if (_coupon && code == null) issues.add(AppStrings.issue('code'));
    if (_coupon && original == null && existing.any((c) => c.id == code)) {
      issues.add(AppStrings.codeTaken);
    }
    final nameAr = _nameAr.text.trim(), nameEn = _nameEn.text.trim();
    final end = _end;
    final after = Offer(
      id:
          original?.id ??
          code ??
          FirebaseFirestore.instance.collection('offers').doc().id,
      name: nameAr,
      names: {'ar': nameAr, if (nameEn.isNotEmpty) 'en': nameEn},
      kind: _kind,
      value: value ?? 0,
      categoryId: _categoryId,
      minSubtotal: minOrder,
      maxDiscount: maxDiscount,
      startsAtMs: _start?.millisecondsSinceEpoch,
      // The day after the last one, at midnight: the end is exclusive.
      endsAtMs: end == null
          ? null
          : DateTime(end.year, end.month, end.day + 1).millisecondsSinceEpoch,
      isActive: _active,
      code: code,
      maxUses: _coupon ? maxUses : null,
      // A coupon keeps its count; only orders change it.
      uses: original?.uses ?? 0,
    );
    issues.addAll([
      for (final i in validateOffer(
        after,
        categoryIds: ref.read(definitionsProvider).keys.toSet(),
      ))
        AppStrings.issue(i.path),
    ]);
    setState(() => _issues = issues.toSet().toList());
    if (issues.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: widget.list.action,
            path: widget.list.pathOf(after),
            before: original?.toJson(),
            after: after.toJson(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(AppStrings.saved)));
      context.pop();
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.saveFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(offersProvider(widget.list)).value;
    if (all == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final id = widget.id;
    final current = id == null
        ? null
        : all.where((o) => o.id == id).firstOrNull;
    if (id != null && current == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.loadError)));
    }
    _load(current);
    final defs = ref.watch(definitionsProvider);
    final theme = Theme.of(context);
    const gap = SizedBox(height: 12);

    Widget dateRow(String label, DateTime? date, {required bool start}) => Row(
      children: [
        Expanded(
          child: Text(
            '$label: ${date == null ? AppStrings.noDate : AppStrings.day(date)}',
          ),
        ),
        TextButton(
          onPressed: () => _pickDate(start: start),
          child: const Text(AppStrings.pick),
        ),
        if (date != null)
          TextButton(
            onPressed: () =>
                setState(() => start ? _start = null : _end = null),
            child: const Text(AppStrings.clear),
          ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(
          id == null
              ? (_coupon ? AppStrings.newCoupon : AppStrings.newOffer)
              : (_coupon ? AppStrings.editCoupon : AppStrings.editOffer),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_coupon) ...[
                TextField(
                  controller: _code,
                  enabled: current == null,
                  textDirection: TextDirection.ltr,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: AppStrings.couponCodeLabel,
                  ),
                ),
                if (current != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      AppStrings.usedTimes(current.uses, current.maxUses),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                gap,
              ],
              TextField(
                controller: _nameAr,
                decoration: const InputDecoration(labelText: AppStrings.nameAr),
              ),
              gap,
              TextField(
                controller: _nameEn,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: AppStrings.nameEn),
              ),
              const SizedBox(height: 20),
              Text(AppStrings.offerKind, style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<OfferKind>(
                segments: [
                  for (final k in OfferKind.values)
                    ButtonSegment(value: k, label: Text(AppStrings.kind(k))),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              gap,
              if (_kind != OfferKind.freeDelivery) ...[
                TextField(
                  controller: _value,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: _kind == OfferKind.percent
                        ? AppStrings.percentValue
                        : AppStrings.amountValue,
                  ),
                ),
                gap,
              ],
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                decoration: const InputDecoration(
                  labelText: AppStrings.appliesTo,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text(AppStrings.wholeOrder),
                  ),
                  for (final d in defs.values)
                    DropdownMenuItem(value: d.id, child: Text(d.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              gap,
              TextField(
                controller: _minOrder,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.minOrder,
                ),
              ),
              gap,
              if (_kind != OfferKind.amount) ...[
                TextField(
                  controller: _maxDiscount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: AppStrings.maxDiscountField,
                  ),
                ),
                gap,
              ],
              dateRow(AppStrings.startDate, _start, start: true),
              dateRow(AppStrings.endDate, _end, start: false),
              if (_coupon) ...[
                gap,
                TextField(
                  controller: _maxUses,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: AppStrings.maxUsesField,
                  ),
                ),
              ],
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(AppStrings.activeLabel),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
              ),
              if (_issues.isNotEmpty) ...[
                gap,
                Text(
                  AppStrings.fixErrors,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                for (final i in _issues)
                  Text(
                    '• $i',
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving ? null : () => _save(all),
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
