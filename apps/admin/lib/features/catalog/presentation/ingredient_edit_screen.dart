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

/// Edits one ingredient (P3-03): names, extra price (one price wherever it
/// is used), availability and its image, picked from the ingredient images.
/// Checked by `validateIngredient`, then an audited save.
class IngredientEditScreen extends ConsumerStatefulWidget {
  const IngredientEditScreen({super.key, required this.ingredientId});

  final String ingredientId;

  @override
  ConsumerState<IngredientEditScreen> createState() =>
      _IngredientEditScreenState();
}

class _IngredientEditScreenState extends ConsumerState<IngredientEditScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _price = TextEditingController();
  Ingredient? _original;
  String? _assetId;
  bool _available = true;
  bool _saving = false;
  List<String> _issues = const [];

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _price.dispose();
    super.dispose();
  }

  void _load(Ingredient i) {
    if (_original != null) return;
    _original = i;
    _nameAr.text = i.names['ar'] ?? i.name;
    _nameEn.text = i.names['en'] ?? '';
    _price.text = AppStrings.egp(i.extraPrice);
    _assetId = i.assetId;
    _available = i.isAvailable;
  }

  Future<void> _save(Set<String> ingredientAssets) async {
    final who = ref.read(adminAccessProvider).value;
    final original = _original;
    if (who is! Granted || original == null || _saving) return;
    final price = AppStrings.parseEgp(_price.text);
    final nameAr = _nameAr.text.trim(), nameEn = _nameEn.text.trim();
    final after = Ingredient(
      id: original.id,
      name: nameAr,
      names: {'ar': nameAr, if (nameEn.isNotEmpty) 'en': nameEn},
      assetId: _assetId ?? original.assetId,
      extraPrice: price ?? 0,
      isAvailable: _available,
      sizeMultipliers: original.sizeMultipliers,
    );
    final issues = [
      if (price == null) '${AppStrings.extraPrice}: ${AppStrings.invalidMoney}',
      for (final i in validateIngredient(
        after,
        ingredientAssets: ingredientAssets,
      ))
        AppStrings.issue(i.path),
    ];
    setState(() => _issues = issues.toSet().toList());
    if (issues.isNotEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'saveIngredient',
            path: 'ingredients/${original.id}',
            before: original.toJson(),
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
    final ingredient = ref
        .watch(ingredientsProvider)
        .value?[widget.ingredientId];
    final assets = ref.watch(assetsProvider).value;
    if (ingredient == null || assets == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _load(ingredient);
    final pickable = {
      for (final e in assets.entries)
        if (e.value.kind == 'ingredient') e.key: e.value,
    };
    const gap = SizedBox(height: 12);
    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.editIngredient)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              gap,
              TextField(
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(
                  labelText: AppStrings.extraPrice,
                  helperText: AppStrings.extraPriceHint,
                ),
              ),
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _available ? AppStrings.available : AppStrings.unavailable,
                ),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              gap,
              Text(
                AppStrings.image,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final e in pickable.entries)
                    InkWell(
                      onTap: () => setState(() => _assetId = e.key),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 72,
                        height: 72,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            width: e.key == _assetId ? 3 : 1,
                            color: e.key == _assetId
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Tooltip(
                          message: e.value.name,
                          child: Image.network(
                            e.value.secureUrl,
                            errorBuilder: (_, _, _) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              if (_issues.isNotEmpty) ...[
                gap,
                Text(
                  AppStrings.fixErrors,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                for (final i in _issues)
                  Text(
                    '• $i',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: FilledButton(
            onPressed: _saving ? null : () => _save(pickable.keys.toSet()),
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
