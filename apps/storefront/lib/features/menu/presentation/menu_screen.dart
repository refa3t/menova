import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/widgets/credit_footer.dart';
import '../../../core/widgets/language_button.dart';
import '../../cart/presentation/cart_button.dart';
import '../domain/menu.dart';
import 'menu_providers.dart';
import 'product_preview.dart';
import 'product_card.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  String? _selectedCategoryId;
  Menu? _precached;

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.appTitle),
        actions: const [LanguageButton(), CartButton()],
      ),
      bottomNavigationBar: const CreditFooter(),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            _ErrorView(onRetry: () => ref.invalidate(menuProvider)),
        data: (menu) {
          if (!identical(_precached, menu)) {
            _precached = menu;
            precacheMenuImages(context, menu);
          }
          if (menu.categories.isEmpty) {
            return Center(child: Text(AppStrings.menuEmpty));
          }
          final selected = menu.categories.firstWhere(
            (c) => c.definition.id == _selectedCategoryId,
            orElse: () => menu.categories.first,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CategoryBar(
                categories: menu.categories,
                selectedId: selected.definition.id,
                onSelected: (id) => setState(() => _selectedCategoryId = id),
              ),
              Expanded(
                child: _ProductGrid(menu: menu, category: selected),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final String selectedId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        children: [
          for (final c in categories)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(
                label: Text(
                  AppStrings.localized(c.definition.name, c.definition.names),
                ),
                selected: c.definition.id == selectedId,
                onSelected: (_) => onSelected(c.definition.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Products of one category, optionally filtered by the category's product
/// groups (e.g. chicken, meats) from its definition. Generic: any category
/// with `productGroups` gets the same chips.
class _ProductGrid extends StatefulWidget {
  const _ProductGrid({required this.menu, required this.category});

  final Menu menu;
  final MenuCategory category;

  @override
  State<_ProductGrid> createState() => _ProductGridState();
}

class _ProductGridState extends State<_ProductGrid> {
  String? _groupId; // null = all

  @override
  void didUpdateWidget(_ProductGrid old) {
    super.didUpdateWidget(old);
    if (old.category.definition.id != widget.category.definition.id) {
      _groupId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final menu = widget.menu;
    if (category.products.isEmpty) {
      return Center(child: Text(AppStrings.categoryEmpty));
    }
    // Only groups that actually have products, in definition order.
    final groups = [
      for (final g in category.definition.productGroups)
        if (category.products.any((p) => p.groupId == g.id)) g,
    ];
    final products = _groupId == null
        ? category.products
        : [
            for (final p in category.products)
              if (p.groupId == _groupId) p,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (groups.isNotEmpty)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final (id, name) in [
                  (null, AppStrings.allGroups),
                  for (final g in groups)
                    (g.id, AppStrings.localized(g.name, g.names)),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _groupId == id,
                      onSelected: (_) => setState(() => _groupId = id),
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 260,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemCount: products.length,
            itemBuilder: (context, i) {
              final p = products[i];
              return ProductCard(
                product: p,
                imageUrl: menu.cardImageUrl(p, category.definition),
                // Until final product images exist, draw the defaults.
                preview: menu.assets.containsKey(p.imageAssetId)
                    ? null
                    : ProductPreview(
                        menu: menu,
                        definition: category.definition,
                        product: p,
                      ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(AppStrings.menuLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
