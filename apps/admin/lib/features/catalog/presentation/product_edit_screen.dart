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
import '../domain/product_ids.dart';

/// Edits (or creates) one product within its category's definition (P3-02):
/// names, description, prices, sizes and options the definition offers,
/// group, availability, display order and default ingredients. Checked
/// with the same validator as the catalog before an audited save.
class ProductEditScreen extends ConsumerStatefulWidget {
  const ProductEditScreen({super.key, this.productId, this.categoryId});

  /// Null for a new product.
  final String? productId;

  /// Category of a new product.
  final String? categoryId;

  @override
  ConsumerState<ProductEditScreen> createState() => _ProductEditScreenState();
}

class _ProductEditScreenState extends ConsumerState<ProductEditScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _description = TextEditingController();
  final _basePrice = TextEditingController();
  final _displayOrder = TextEditingController(text: '0');
  final _sizeDeltas = <String, TextEditingController>{};
  final _optionDeltas = <String, TextEditingController>{};
  final _defaults = <ProductIngredient>[];
  String? _categoryId;
  String? _groupId;
  bool _available = true;
  Product? _original;
  bool _loaded = false;
  bool _saving = false;
  List<String> _issues = const [];

  @override
  void dispose() {
    for (final c in [
      _nameAr,
      _nameEn,
      _description,
      _basePrice,
      _displayOrder,
      ..._sizeDeltas.values,
      ..._optionDeltas.values,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _load(List<Product> products, Map<String, CategoryDefinition> defs) {
    if (_loaded) return;
    final p = products.where((p) => p.id == widget.productId).firstOrNull;
    _original = p;
    _categoryId = p?.categoryId ?? widget.categoryId ?? defs.keys.firstOrNull;
    final def = defs[_categoryId];
    _nameAr.text = p?.names['ar'] ?? p?.name ?? '';
    _nameEn.text = p?.names['en'] ?? '';
    _description.text = p?.description ?? '';
    _basePrice.text = p == null ? '' : AppStrings.egp(p.basePrice);
    _displayOrder.text = '${p?.displayOrder ?? products.length}';
    _groupId = p?.groupId;
    _available = p?.isAvailable ?? true;
    _defaults
      ..clear()
      ..addAll(p?.defaults ?? const []);
    for (final s in def?.sizes ?? const <SizeOption>[]) {
      _sizeDeltas[s.id] = TextEditingController(
        text: AppStrings.egp(p?.sizeDeltas[s.id] ?? 0),
      );
    }
    for (final g in def?.optionGroups ?? const <OptionGroup>[]) {
      for (final c in g.choices) {
        _optionDeltas[c.id] = TextEditingController(
          text: AppStrings.egp(p?.optionDeltas[c.id] ?? 0),
        );
      }
    }
    _loaded = true;
  }

  /// The product as entered, or null with [_issues] set.
  Product? _build(
    CategoryDefinition def,
    List<Product> products,
    Map<String, Ingredient> ingredients,
  ) {
    final money = <String>[];
    int moneyOf(TextEditingController c, String label) {
      final v = AppStrings.parseEgp(c.text);
      if (v == null) money.add('$label: ${AppStrings.invalidMoney}');
      return v ?? 0;
    }

    final base = moneyOf(_basePrice, AppStrings.basePrice);
    final sizes = {
      for (final e in _sizeDeltas.entries)
        e.key: moneyOf(e.value, AppStrings.sizePrices),
    };
    final options = {
      for (final e in _optionDeltas.entries)
        e.key: moneyOf(e.value, AppStrings.optionPrices),
    };
    final order = int.tryParse(_displayOrder.text.trim());
    if (order == null) money.add(AppStrings.issue('displayOrder'));
    final nameAr = _nameAr.text.trim(), nameEn = _nameEn.text.trim();
    final id =
        _original?.id ??
        newProductId(
          categoryId: def.id,
          name: nameEn.isNotEmpty ? nameEn : nameAr,
          taken: {for (final p in products) p.id},
        );
    final product = Product(
      id: id,
      categoryId: def.id,
      name: nameAr,
      names: {'ar': nameAr, if (nameEn.isNotEmpty) 'en': nameEn},
      description: _description.text.trim(),
      basePrice: base,
      imageAssetId: _original?.imageAssetId ?? 'final_$id',
      defaults: List.of(_defaults),
      isAvailable: _available,
      sizeDeltas: sizes,
      optionDeltas: options,
      displayOrder: order ?? 0,
      groupId: _groupId,
    );
    final issues = [
      ...money,
      for (final i in validateProduct(
        product,
        def,
        ingredientIds: ingredients.keys.toSet(),
      ))
        AppStrings.issue(i.path),
    ];
    setState(() => _issues = issues.toSet().toList());
    return issues.isEmpty ? product : null;
  }

  Future<void> _save(
    CategoryDefinition def,
    List<Product> products,
    Map<String, Ingredient> ingredients,
  ) async {
    final who = ref.read(adminAccessProvider).value;
    if (who is! Granted || _saving) return;
    final product = _build(def, products, ingredients);
    if (product == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(auditedWriterProvider)
          .write(
            who: who,
            action: 'saveProduct',
            path: 'products/${product.id}',
            before: _original?.toJson(),
            after: product.toJson(),
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
    final defs = ref.watch(definitionsProvider);
    final products = ref.watch(productsProvider).value;
    final ingredients = ref.watch(ingredientsProvider).value;
    if (products == null || ingredients == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _load(products, defs);
    final def = defs[_categoryId];
    if (def == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.loadError)));
    }
    String ingName(String id) =>
        ingredients[id]?.names['ar'] ?? ingredients[id]?.name ?? id;
    final addable = [
      for (final id in def.allowedIngredientIds)
        if (ingredients.containsKey(id) &&
            !_defaults.any((d) => d.ingredientId == id))
          id,
    ];
    Widget money(TextEditingController c, String label, {String? hint}) =>
        TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: label, helperText: hint),
        );
    const gap = SizedBox(height: 12);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _original == null ? AppStrings.newProduct : AppStrings.editProduct,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_original == null)
                DropdownButtonFormField<String>(
                  initialValue: def.id,
                  decoration: const InputDecoration(
                    labelText: AppStrings.category,
                  ),
                  items: [
                    for (final d in defs.values)
                      DropdownMenuItem(
                        value: d.id,
                        child: Text(d.names['ar'] ?? d.name),
                      ),
                  ],
                  onChanged: (id) => setState(() {
                    // A new product starts over in the other category.
                    _categoryId = id;
                    _groupId = null;
                    _defaults.clear();
                    _sizeDeltas.clear();
                    _optionDeltas.clear();
                    _loaded = false;
                    _load(products, defs);
                  }),
                )
              else
                Text('${AppStrings.category}: ${def.names['ar'] ?? def.name}'),
              gap,
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
                controller: _description,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: AppStrings.description,
                ),
              ),
              money(
                _basePrice,
                AppStrings.basePrice,
                hint: AppStrings.basePriceHint,
              ),
              if (def.sizes.isNotEmpty) ...[
                gap,
                Text(
                  AppStrings.sizePrices,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final s in def.sizes)
                      SizedBox(
                        width: 150,
                        child: money(
                          _sizeDeltas[s.id]!,
                          s.names['ar'] ?? s.name,
                        ),
                      ),
                  ],
                ),
              ],
              if (_optionDeltas.isNotEmpty) ...[
                gap,
                Text(
                  AppStrings.optionPrices,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Wrap(
                  spacing: 12,
                  children: [
                    for (final g in def.optionGroups)
                      for (final c in g.choices)
                        SizedBox(
                          width: 180,
                          child: money(
                            _optionDeltas[c.id]!,
                            c.names['ar'] ?? c.name,
                          ),
                        ),
                  ],
                ),
              ],
              if (def.productGroups.isNotEmpty) ...[
                gap,
                DropdownButtonFormField<String?>(
                  initialValue: _groupId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.group,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text(AppStrings.noGroup),
                    ),
                    for (final g in def.productGroups)
                      DropdownMenuItem(
                        value: g.id,
                        child: Text(g.names['ar'] ?? g.name),
                      ),
                  ],
                  onChanged: (v) => setState(() => _groupId = v),
                ),
              ],
              gap,
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _available ? AppStrings.available : AppStrings.unavailable,
                ),
                value: _available,
                onChanged: (v) => setState(() => _available = v),
              ),
              SizedBox(
                width: 160,
                child: TextField(
                  controller: _displayOrder,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: AppStrings.displayOrder,
                  ),
                ),
              ),
              gap,
              Text(
                AppStrings.defaults,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              for (final (i, d) in _defaults.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(ingName(d.ingredientId)),
                  subtitle: Row(
                    children: [
                      const Text('${AppStrings.qty}: '),
                      IconButton(
                        onPressed: d.qty > 1
                            ? () => setState(
                                () => _defaults[i] = _with(d, qty: d.qty - 1),
                              )
                            : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${d.qty}'),
                      IconButton(
                        onPressed: () => setState(
                          () => _defaults[i] = _with(d, qty: d.qty + 1),
                        ),
                        icon: const Icon(Icons.add),
                      ),
                      const SizedBox(width: 12),
                      const Text(AppStrings.removable),
                      Switch(
                        value: d.removable,
                        onChanged: (v) => setState(
                          () => _defaults[i] = _with(d, removable: v),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    onPressed: () => setState(() => _defaults.removeAt(i)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              if (addable.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: PopupMenuButton<String>(
                    onSelected: (id) => setState(
                      () => _defaults.add(
                        ProductIngredient(
                          ingredientId: id,
                          qty: 1,
                          removable: true,
                        ),
                      ),
                    ),
                    itemBuilder: (_) => [
                      for (final id in addable)
                        PopupMenuItem(value: id, child: Text(ingName(id))),
                    ],
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add),
                          SizedBox(width: 8),
                          Text(AppStrings.addIngredient),
                        ],
                      ),
                    ),
                  ),
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
            onPressed: _saving ? null : () => _save(def, products, ingredients),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? AppStrings.saving : AppStrings.save),
          ),
        ),
      ),
    );
  }

  static ProductIngredient _with(
    ProductIngredient d, {
    int? qty,
    bool? removable,
  }) => ProductIngredient(
    ingredientId: d.ingredientId,
    qty: qty ?? d.qty,
    removable: removable ?? d.removable,
    refundOnRemove: d.refundOnRemove,
    refundAmount: d.refundAmount,
  );
}
