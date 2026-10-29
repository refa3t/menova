import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';

/// Products by category (P3-02): search, open to edit, and a quick
/// availability switch (each switch is an audited save).
class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  String? _category;
  String _query = '';

  Future<void> _setAvailable(Product p, bool value) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted) return;
    final after = Product.fromJson({...p.toJson(), 'isAvailable': value});
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'saveProduct',
            path: 'products/${p.id}',
            before: p.toJson(),
            after: after.toJson(),
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
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.products)),
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
          final shown = [
            for (final p in all)
              if ((_category == null || p.categoryId == _category) &&
                  (_query.isEmpty ||
                      p.name.contains(_query) ||
                      (p.names['en'] ?? '').toLowerCase().contains(
                        _query.toLowerCase(),
                      )))
                p,
          ];
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
              const SizedBox(height: 12),
              for (final p in shown)
                Card(
                  child: ListTile(
                    minTileHeight: 64,
                    title: Text(p.name),
                    subtitle: Text(
                      '${defs[p.categoryId]?.names['ar'] ?? p.categoryId}'
                      ' · ${AppStrings.price(p.basePrice)}',
                    ),
                    onTap: () => context.push('/products/${p.id}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          p.isAvailable
                              ? AppStrings.available
                              : AppStrings.unavailable,
                        ),
                        Switch(
                          value: p.isAvailable,
                          onChanged: (v) => _setAvailable(p, v),
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
