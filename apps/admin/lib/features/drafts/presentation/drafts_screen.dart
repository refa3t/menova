import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../catalog/data/audited_writer.dart';
import '../../catalog/data/catalog_providers.dart';
import '../data/drafts_providers.dart';
import '../domain/draft.dart';

/// Pending drafts (P3-09): what each changes (live → draft), and publishing
/// them. Each publish is checked like a save, applied on top of the live
/// record and audited, and drops its draft in the same write.
class DraftsScreen extends ConsumerStatefulWidget {
  const DraftsScreen({super.key});

  @override
  ConsumerState<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends ConsumerState<DraftsScreen> {
  var _publishing = false;

  Json? _live(Draft d) => switch (d.kind) {
    DraftKind.product =>
      ref
          .read(productsProvider)
          .value
          ?.where((p) => p.id == d.recordId)
          .firstOrNull
          ?.toJson(),
    DraftKind.ingredient =>
      ref.read(ingredientsProvider).value?[d.recordId]?.toJson(),
  };

  /// Why [after] cannot be published, empty when it can.
  List<String> _problems(Draft d, Json after) {
    try {
      switch (d.kind) {
        case DraftKind.product:
          final p = Product.fromJson(after);
          final def = ref.read(definitionsProvider)[p.categoryId];
          if (def == null) return const ['categoryId'];
          return [
            for (final i in validateProduct(
              p,
              def,
              ingredientIds: (ref.read(ingredientsProvider).value ?? const {})
                  .keys
                  .toSet(),
            ))
              i.path,
          ];
        case DraftKind.ingredient:
          return [
            for (final i in validateIngredient(
              Ingredient.fromJson(after),
              ingredientAssets: {
                for (final e
                    in (ref.read(assetsProvider).value ?? const {}).entries)
                  if (e.value.kind == 'ingredient') e.key,
              },
            ))
              i.path,
          ];
      }
    } on Object {
      return const ['format'];
    }
  }

  Future<void> _publish(List<Draft> drafts) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted || _publishing) return;
    setState(() => _publishing = true);
    final messenger = ScaffoldMessenger.of(context);
    var done = 0;
    final failed = <String>[];
    for (final d in drafts) {
      final live = _live(d);
      final after = d.applyTo(live);
      final name = '${after['name'] ?? d.recordId}';
      if (_problems(d, after).isNotEmpty) {
        failed.add(name);
        continue;
      }
      try {
        await ref
            .read(auditedWriterProvider)
            .write(
              who: who,
              action: d.kind == DraftKind.product
                  ? 'saveProduct'
                  : 'saveIngredient',
              path: d.target,
              before: live,
              after: after,
              alsoDelete: 'drafts/${d.id}',
            );
        done++;
      } on Object {
        failed.add(name);
      }
    }
    if (mounted) setState(() => _publishing = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            AppStrings.published(done),
            if (failed.isNotEmpty) AppStrings.notPublished(failed.join('، ')),
          ].join('\n'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final drafts = ref.watch(draftsProvider);
    // Live records, to show what each draft changes.
    ref.watch(productsProvider);
    ref.watch(ingredientsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.drafts)),
      body: drafts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (list) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  AppStrings.draftsNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(AppStrings.noDrafts),
                  )
                else ...[
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FilledButton.icon(
                      onPressed: _publishing ? null : () => _publish(list),
                      icon: const Icon(Icons.publish),
                      label: Text(
                        _publishing
                            ? AppStrings.publishing
                            : AppStrings.publishAll(list.length),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final d in list)
                    _DraftCard(
                      draft: d,
                      live: _live(d),
                      publishing: _publishing,
                      onPublish: () => _publish([d]),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DraftCard extends ConsumerWidget {
  const _DraftCard({
    required this.draft,
    required this.live,
    required this.publishing,
    required this.onPublish,
  });

  final Draft draft;
  final Json? live;
  final bool publishing;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final after = draft.applyTo(live);
    final conflicts = draft.conflictsWith(live);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppStrings.draftKind(draft.kind.name)}: ${after['name'] ?? draft.recordId}'
              '${draft.isNew ? ' · ${AppStrings.newRecord}' : ''}',
              style: theme.textTheme.titleMedium,
            ),
            Text(
              '${draft.byEmail ?? draft.by ?? ''} · ${AppStrings.when(draft.at)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (!draft.isNew)
              for (final e in draft.changes.entries)
                Text(
                  '${AppStrings.field(e.key)}: '
                  '${AppStrings.fieldValue(e.key, live?[e.key])} ← '
                  '${AppStrings.fieldValue(e.key, e.value)}',
                ),
            if (conflicts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  AppStrings.changedSince(
                    conflicts.map(AppStrings.field).join('، '),
                  ),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: publishing ? null : onPublish,
                  child: const Text(AppStrings.publish),
                ),
                OutlinedButton(
                  onPressed: () => context.push(
                    draft.kind == DraftKind.product
                        ? '/products/${draft.recordId}'
                        : '/ingredients/${draft.recordId}',
                  ),
                  child: const Text(AppStrings.open),
                ),
                TextButton(
                  onPressed: () => ref.read(draftWriterProvider).discard(draft),
                  child: const Text(AppStrings.discardDraft),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
