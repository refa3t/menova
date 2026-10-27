import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_drawer.dart';
import '../../../core/widgets/credit_footer.dart';
import '../../../core/widgets/feature_strip.dart';
import '../../../core/widgets/top_bar.dart';
import '../../cart/presentation/cart_fab.dart';
import '../domain/menu.dart';
import 'menu_providers.dart';
import 'menu_widgets.dart';
import 'product_card.dart';

/// One category's page (owner request): its product groups, search and
/// product cards. Generic over categories; the home page lists categories.
class CategoryScreen extends ConsumerStatefulWidget {
  const CategoryScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends ConsumerState<CategoryScreen> {
  String? _groupId; // null = all
  String _query = '';

  void _search(String q) => setState(() => _query = q.trim().toLowerCase());

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      drawer: const AppDrawer(active: NavItem.menu),
      floatingActionButton: menu.hasValue
          ? CartFab(menu: menu.requireValue)
          : null,
      appBar: TopBar(active: NavItem.menu, onSearch: _search),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            MenuErrorView(onRetry: () => ref.invalidate(menuProvider)),
        data: (menu) {
          final category = menu.categories
              .where((c) => c.definition.id == widget.categoryId)
              .firstOrNull;
          if (category == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(AppStrings.categoryNotFound),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => context.go('/'),
                    child: Text(AppStrings.navHome),
                  ),
                ],
              ),
            );
          }
          return _body(context, menu, category);
        },
      ),
    );
  }

  bool _matches(Product p, Menu menu) {
    if (_query.isEmpty) return true;
    final names = [
      p.name,
      AppStrings.localized(p.name, p.names),
      for (final d in p.defaults)
        if (menu.ingredients[d.ingredientId] case final i?) ...[
          i.name,
          AppStrings.localized(i.name, i.names),
        ],
    ];
    return names.any((n) => n.toLowerCase().contains(_query));
  }

  Widget _body(BuildContext context, Menu menu, MenuCategory category) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = AppLayout.gutter(width);
    final def = category.definition;
    final groups = [
      for (final g in def.productGroups)
        if (category.products.any((p) => p.groupId == g.id)) g,
    ];
    final products = [
      for (final p in category.products)
        if ((_groupId == null || p.groupId == _groupId) && _matches(p, menu)) p,
    ];

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(gutter, 16, gutter, 0),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.canPop() ? context.pop() : context.go('/'),
                    icon: const BackButtonIcon(),
                    label: Text(AppStrings.navHome),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.text,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 0),
                child: Text(
                  AppStrings.localized(def.name, def.names),
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (width < AppLayout.tablet)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 0),
                  child: TextField(
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                  ),
                ),
              if (groups.isNotEmpty)
                Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 8),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      GroupChip(
                        label: AppStrings.allGroups,
                        icon: Icons.grid_view_rounded,
                        selected: _groupId == null,
                        onTap: () => setState(() => _groupId = null),
                      ),
                      for (final g in groups)
                        GroupChip(
                          label: AppStrings.localized(g.name, g.names),
                          icon: Icons.local_pizza_outlined,
                          selected: _groupId == g.id,
                          onTap: () => setState(() => _groupId = g.id),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (products.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(48),
                  child: Center(child: Text(AppStrings.noResults)),
                )
              else
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: gutter),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 230,
                          mainAxisSpacing: 18,
                          crossAxisSpacing: 18,
                          childAspectRatio: 0.66,
                        ),
                    itemCount: products.length,
                    itemBuilder: (context, i) => ProductCard(
                      menu: menu,
                      category: category,
                      product: products[i],
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 40, gutter, 24),
                child: const FeatureStrip(),
              ),
              const CreditFooter(),
            ],
          ),
        ),
      ),
    );
  }
}
