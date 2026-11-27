import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/admin_app_bar.dart';
import '../data/catalog_providers.dart';
import '../domain/catalog_list.dart';
import 'catalog_list_widgets.dart';

/// Products by category (P3-02): image, compact prices, filters by category
/// and status, search, open to edit, a quick availability switch, and
/// selecting several to stop or start them at once (each switch and each
/// selected product is an audited save).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _category;
  StatusFilter _status = StatusFilter.all;
  String _query = '';
  final _selected = <String>{};
  (int, int)? _progress;

  /// Start clears a stop until a time; stop lasts until started again.
  Future<void> _setAvailable(Product p, bool value) => saveAvailabilityChange(
    context: context,
    ref: ref,
    change: productAvailabilityChanges([p], value).firstOrNull,
  );

  /// «إيقاف لنهاية اليوم»: back by itself at the end of the business day.
  Future<void> _stopForDay(Product p) async {
    final until = await stopForDayUntil(ref);
    if (!mounted) return;
    await saveAvailabilityChange(
      context: context,
      ref: ref,
      change: productStopUntilChanges([p], until).firstOrNull,
      doneMessage: AppStrings.stoppedForDay(
        DateTime.fromMillisecondsSinceEpoch(until),
      ),
    );
  }

  Future<void> _setSelected(
    List<Product> all,
    bool value, {
    bool forDay = false,
  }) async {
    final chosen = [
      for (final p in all)
        if (_selected.contains(p.id)) p,
    ];
    final until = forDay ? await stopForDayUntil(ref) : null;
    if (!mounted) return;
    final changes = until == null
        ? productAvailabilityChanges(chosen, value)
        : productStopUntilChanges(chosen, until);
    final done = await runBulkAvailability(
      context: context,
      ref: ref,
      value: value,
      changes: changes,
      confirmText: until == null
          ? null
          : AppStrings.confirmStopForDay(
              changes.length,
              DateTime.fromMillisecondsSinceEpoch(until),
            ),
      onProgress: (d, t) {
        if (mounted) setState(() => _progress = (d, t));
      },
    );
    if (mounted) {
      setState(() {
        _progress = null;
        if (done) _selected.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final defs = ref.watch(definitionsProvider);
    final products = ref.watch(productsProvider);
    final assets = ref.watch(assetsProvider).value ?? const {};
    final drafts = ref.watch(draftTargetsProvider);
    return Scaffold(
      appBar: const AdminAppBar(title: Text(AppStrings.products)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(
          '/products/new${_category == null ? '' : '?category=$_category'}',
        ),
        icon: const Icon(Icons.add),
        label: const Text(AppStrings.newProduct),
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (all) {
          // Rebuilt when the next product stopped until a time comes back.
          final now = ref.watch(
            availabilityNowProvider(
              earliestPendingUntil([
                for (final p in all) p.unavailableUntil,
              ], DateTime.now()),
            ),
          );
          final shown = filterProducts(
            all,
            categoryId: _category,
            status: _status,
            query: _query,
            draftTargets: drafts,
            now: now,
          );
          final busy = _progress != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Text(AppStrings.allCategories),
                    selected: _category == null,
                    onSelected: (_) => setState(() => _category = null),
                  ),
                  for (final d in defs.values)
                    ChoiceChip(
                      label: Text(d.names['ar'] ?? d.name),
                      selected: _category == d.id,
                      onSelected: (_) => setState(() => _category = d.id),
                    ),
                  SizedBox(
                    width: 240,
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: AppStrings.searchProducts,
                      ),
                      onChanged: (q) => setState(() => _query = q.trim()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StatusFilterChips(
                value: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: 12),
              if (_selected.isNotEmpty || busy)
                BulkAvailabilityBar(
                  selected: _selected.length,
                  progress: _progress,
                  onSelectAllShown: shown.isEmpty
                      ? null
                      : () => setState(
                          () => _selected.addAll([for (final p in shown) p.id]),
                        ),
                  onClear: () => setState(_selected.clear),
                  onSet: (v) => _setSelected(all, v),
                  onStopForDay: () => _setSelected(all, false, forDay: true),
                ),
              if (shown.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text(AppStrings.noMatches)),
                ),
              for (final p in shown)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    contentPadding: const EdgeInsetsDirectional.only(
                      start: 4,
                      end: 12,
                    ),
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _selected.contains(p.id),
                          onChanged: busy
                              ? null
                              : (v) => setState(
                                  () => v == true
                                      ? _selected.add(p.id)
                                      : _selected.remove(p.id),
                                ),
                        ),
                        CatalogThumb(asset: assets[p.imageAssetId]),
                      ],
                    ),
                    title: Text(p.name),
                    subtitle: Text(
                      '${defs[p.categoryId]?.names['ar'] ?? p.categoryId}'
                      ' · ${AppStrings.prices(sizePrices(p, defs[p.categoryId]))}'
                      '${drafts.contains('products/${p.id}') ? ' · ${AppStrings.hasDraft}' : ''}',
                    ),
                    onTap: () => context.push('/products/${p.id}'),
                    trailing: AvailabilityControls(
                      availableNow: p.isAvailableAt(now),
                      stoppedUntil: pendingUntil(
                        isAvailable: p.isAvailable,
                        unavailableUntil: p.unavailableUntil,
                        now: now,
                      ),
                      onSet: busy ? null : (v) => _setAvailable(p, v),
                      onStopForDay: busy ? null : () => _stopForDay(p),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
