import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';

/// Show/hide and order the developer's categories on the home page (P3-05).
/// Only categories that have a definition appear; none can be created here.
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    List<(CategoryContent, CategoryContent)> changes,
  ) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted) return;
    final writer = ref.read(auditedWriterProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final (before, after) in changes) {
        await writer.write(
          who: who,
          action: 'setCategoryVisibility',
          path: 'categoryContent/${after.categoryId}',
          before: before.toJson(),
          after: after.toJson(),
        );
      }
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.saveFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defs = ref.watch(definitionsProvider);
    final contents = ref.watch(categoryContentProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.categories)),
      body: contents.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (all) {
          final list = [
            for (final c in all)
              if (defs.containsKey(c.categoryId)) c,
          ];
          CategoryContent withOrder(CategoryContent c, int order) =>
              CategoryContent(
                categoryId: c.categoryId,
                isVisible: c.isVisible,
                displayOrder: order,
              );
          // Moving swaps two neighbours and renumbers them 0..n.
          void move(int i, int j) => _save(context, ref, [
            (list[i], withOrder(list[i], j)),
            (list[j], withOrder(list[j], i)),
          ]);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(AppStrings.categoriesNote),
              const SizedBox(height: 12),
              for (final (i, c) in list.indexed)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    title: Text(
                      defs[c.categoryId]!.names['ar'] ??
                          defs[c.categoryId]!.name,
                    ),
                    subtitle: Text(
                      c.isVisible
                          ? AppStrings.visibleOnSite
                          : AppStrings.hiddenOnSite,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: AppStrings.moveUp,
                          onPressed: i == 0 ? null : () => move(i, i - 1),
                          icon: const Icon(Icons.arrow_upward),
                        ),
                        IconButton(
                          tooltip: AppStrings.moveDown,
                          onPressed: i == list.length - 1
                              ? null
                              : () => move(i, i + 1),
                          icon: const Icon(Icons.arrow_downward),
                        ),
                        Switch(
                          value: c.isVisible,
                          onChanged: (v) => _save(context, ref, [
                            (
                              c,
                              CategoryContent(
                                categoryId: c.categoryId,
                                isVisible: v,
                                displayOrder: c.displayOrder,
                              ),
                            ),
                          ]),
                        ),
                      ],
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
