import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';
import '../data/audited_writer.dart';
import '../data/catalog_providers.dart';

/// Checks the live catalog against the definitions (P3-06) and lets the
/// admin take broken products off sale (audited). Runs on demand: Spark has
/// no scheduled server jobs; the storefront also hides any category whose
/// definition is invalid (fail-closed).
class CatalogCheckScreen extends ConsumerStatefulWidget {
  const CatalogCheckScreen({super.key});

  @override
  ConsumerState<CatalogCheckScreen> createState() => _CatalogCheckScreenState();
}

class _CatalogCheckScreenState extends ConsumerState<CatalogCheckScreen> {
  bool _busy = false;

  Future<void> _disable(List<Product> broken) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted || _busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      for (final p in broken.where((p) => p.isAvailable)) {
        await ref
            .read(auditedWriterProvider)
            .write(
              who: who,
              action: 'validateCatalog',
              path: 'products/${p.id}',
              before: p.toJson(),
              after: {...p.toJson(), 'isAvailable': false},
            );
      }
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.disabledDone)),
      );
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text(AppStrings.saveFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final defs = ref.watch(definitionsProvider);
    final products = ref.watch(productsProvider).value;
    final ingredients = ref.watch(ingredientsProvider).value;
    final assets = ref.watch(assetsProvider).value;
    if (products == null || ingredients == null || assets == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final findings = checkCatalog(
      definitions: defs,
      products: products,
      ingredients: ingredients,
      ingredientAssets: {
        for (final a in assets.values)
          if (a.kind == 'ingredient') a.id,
      },
    );
    final byId = {for (final p in products) p.id: p};
    final broken = [
      for (final f in findings)
        if (f.kind == 'product' && byId[f.id] != null) byId[f.id]!,
    ];
    String title(CatalogFinding f) => f.kind == 'product'
        ? '${AppStrings.productLabel}: ${byId[f.id]?.name ?? f.id}'
        : '${AppStrings.ingredientLabel}: '
              '${ingredients[f.id]?.names['ar'] ?? ingredients[f.id]?.name ?? f.id}';

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.catalogCheck)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(AppStrings.catalogNote),
          const SizedBox(height: 16),
          if (findings.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.check_circle_outline),
                title: Text(AppStrings.catalogOk),
              ),
            )
          else ...[
            Text(
              AppStrings.findings(findings.length),
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final f in findings)
              Card(
                child: ListTile(
                  title: Text(title(f)),
                  subtitle: Text(
                    {
                      for (final i in f.issues) AppStrings.issue(i.path),
                    }.join('\n'),
                  ),
                  trailing: const Icon(Icons.chevron_left),
                  onTap: () => context.push(
                    f.kind == 'product'
                        ? '/products/${f.id}'
                        : '/ingredients/${f.id}',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            if (broken.any((p) => p.isAvailable))
              FilledButton.icon(
                onPressed: _busy ? null : () => _disable(broken),
                icon: const Icon(Icons.block),
                label: const Text(AppStrings.disableBroken),
              ),
          ],
        ],
      ),
    );
  }
}
