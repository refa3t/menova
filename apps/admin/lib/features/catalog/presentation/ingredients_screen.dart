import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../data/catalog_providers.dart';
import '../domain/catalog_list.dart';
import 'catalog_list_widgets.dart';

/// Every ingredient with its image, extra price, the categories that use it
/// and a quick availability switch (P3-03), with filters by category and
/// status, and selecting several to stop or start at once. An unavailable
/// ingredient can no longer be added as an extra.
class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  String? _category;
  StatusFilter _status = StatusFilter.all;
  String _query = '';
  final _selected = <String>{};
  (int, int)? _progress;

  /// Start clears a stop until a time; stop lasts until started again.
  Future<void> _setAvailable(Ingredient i, bool value) =>
      saveAvailabilityChange(
        context: context,
        ref: ref,
        change: ingredientAvailabilityChanges([i], value).firstOrNull,
      );

  /// «إيقاف لنهاية اليوم»: back by itself at the end of the business day.
  Future<void> _stopForDay(Ingredient i) async {
    final until = await stopForDayUntil(ref);
    if (!mounted) return;
    await saveAvailabilityChange(
      context: context,
      ref: ref,
      change: ingredientStopUntilChanges([i], until).firstOrNull,
      doneMessage: AppStrings.stoppedForDay(
        DateTime.fromMillisecondsSinceEpoch(until),
      ),
    );
  }

  Future<void> _setSelected(
    Map<String, Ingredient> all,
    bool value, {
    bool forDay = false,
  }) async {
    final chosen = [for (final id in _selected) ?all[id]];
    final until = forDay ? await stopForDayUntil(ref) : null;
    if (!mounted) return;
    final changes = until == null
        ? ingredientAvailabilityChanges(chosen, value)
        : ingredientStopUntilChanges(chosen, until);
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
    final ingredients = ref.watch(ingredientsProvider);
    final assets = ref.watch(assetsProvider).value ?? const {};
    final drafts = ref.watch(draftTargetsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.ingredients)),
      body: ingredients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (all) {
          String ar(Ingredient i) => i.names['ar'] ?? i.name;
          // Rebuilt when the next ingredient stopped until a time comes back.
          final now = ref.watch(
            availabilityNowProvider(
              earliestPendingUntil([
                for (final i in all.values) i.unavailableUntil,
              ], DateTime.now()),
            ),
          );
          final shown = filterIngredients(
            all.values,
            category: _category == null ? null : defs[_category],
            status: _status,
            query: _query,
            draftTargets: drafts,
            now: now,
          );
          final busy = _progress != null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(AppStrings.ingredientsNote),
              const SizedBox(height: 8),
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
                    width: 280,
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
                          () => _selected.addAll([for (final i in shown) i.id]),
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
              for (final i in shown)
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
                          value: _selected.contains(i.id),
                          onChanged: busy
                              ? null
                              : (v) => setState(
                                  () => v == true
                                      ? _selected.add(i.id)
                                      : _selected.remove(i.id),
                                ),
                        ),
                        CatalogThumb(asset: assets[i.assetId]),
                      ],
                    ),
                    title: Text(ar(i)),
                    subtitle: Text(
                      '${AppStrings.price(i.extraPrice)} · ${AppStrings.usedIn}: '
                      '${[for (final d in defs.values)
                        if (d.allowedIngredientIds.contains(i.id)) d.names['ar'] ?? d.name].join('، ')}'
                      '${drafts.contains('ingredients/${i.id}') ? ' · ${AppStrings.hasDraft}' : ''}',
                    ),
                    onTap: () => context.push('/ingredients/${i.id}'),
                    trailing: AvailabilityControls(
                      availableNow: i.isAvailableAt(now),
                      stoppedUntil: pendingUntil(
                        isAvailable: i.isAvailable,
                        unavailableUntil: i.unavailableUntil,
                        now: now,
                      ),
                      onSet: busy ? null : (v) => _setAvailable(i, v),
                      onStopForDay: busy ? null : () => _stopForDay(i),
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
