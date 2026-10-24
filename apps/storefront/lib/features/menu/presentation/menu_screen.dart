import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../domain/menu.dart';
import 'menu_providers.dart';
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
      appBar: AppBar(title: const Text(AppStrings.appTitle)),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _ErrorView(onRetry: () => ref.invalidate(menuProvider)),
        data: (menu) {
          if (!identical(_precached, menu)) {
            _precached = menu;
            precacheMenuImages(context, menu);
          }
          if (menu.categories.isEmpty) {
            return const Center(child: Text(AppStrings.menuEmpty));
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
              Expanded(child: _ProductGrid(menu: menu, category: selected)),
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
                label: Text(c.definition.name),
                selected: c.definition.id == selectedId,
                onSelected: (_) => onSelected(c.definition.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  const _ProductGrid({required this.menu, required this.category});

  final Menu menu;
  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    if (category.products.isEmpty) {
      return const Center(child: Text(AppStrings.categoryEmpty));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.78,
      ),
      itemCount: category.products.length,
      itemBuilder: (context, i) {
        final p = category.products[i];
        return ProductCard(
          product: p,
          imageUrl: menu.cardImageUrl(p, category.definition),
        );
      },
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
          const Text(AppStrings.menuLoadError),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text(AppStrings.retry)),
        ],
      ),
    );
  }
}
