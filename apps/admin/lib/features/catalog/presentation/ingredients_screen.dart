import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';

/// Every ingredient with its image, extra price, the categories that use it
/// and a quick availability switch (P3-03). An unavailable ingredient can no
/// longer be added as an extra.
class IngredientsScreen extends ConsumerStatefulWidget {
  const IngredientsScreen({super.key});

  @override
  ConsumerState<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends ConsumerState<IngredientsScreen> {
  String _query = '';

  Future<void> _setAvailable(Ingredient i, bool value) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted) return;
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'saveIngredient',
            path: 'ingredients/${i.id}',
            before: i.toJson(),
            after: {...i.toJson(), 'isAvailable': value},
          );
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text(AppStrings.saveFailed)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defs = ref.watch(definitionsProvider);
    final ingredients = ref.watch(ingredientsProvider);
    final assets = ref.watch(assetsProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.ingredients)),
      body: ingredients.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text(AppStrings.loadError)),
        data: (all) {
          String ar(Ingredient i) => i.names['ar'] ?? i.name;
          final shown = [
            for (final i in all.values)
              if (_query.isEmpty ||
                  ar(i).contains(_query) ||
                  (i.names['en'] ?? '').toLowerCase().contains(
                    _query.toLowerCase(),
                  ))
                i,
          ]..sort((a, b) => ar(a).compareTo(ar(b)));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(AppStrings.ingredientsNote),
              const SizedBox(height: 8),
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
              const SizedBox(height: 12),
              for (final i in shown)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    leading: SizedBox.square(
                      dimension: 44,
                      child: assets[i.assetId] == null
                          ? const Icon(Icons.image_not_supported_outlined)
                          : Image.network(
                              assets[i.assetId]!.secureUrl,
                              errorBuilder: (_, _, _) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                    ),
                    title: Text(ar(i)),
                    subtitle: Text(
                      '${AppStrings.price(i.extraPrice)} · ${AppStrings.usedIn}: '
                      '${[for (final d in defs.values)
                        if (d.allowedIngredientIds.contains(i.id)) d.names['ar'] ?? d.name].join('، ')}',
                    ),
                    onTap: () => context.push('/ingredients/${i.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          i.isAvailable
                              ? AppStrings.available
                              : AppStrings.unavailable,
                        ),
                        Switch(
                          value: i.isAvailable,
                          onChanged: (v) => _setAvailable(i, v),
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
