import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/credit_footer.dart';
import '../../../core/widgets/feature_strip.dart';
import '../../../core/widgets/top_bar.dart';
import '../domain/menu.dart';
import 'menu_providers.dart';
import 'product_card.dart';
import 'product_preview.dart';

/// Home page (reference design, P1-A13..A20): header, hero, category and
/// group chips, product cards, features and footer. Generic over categories.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _productsKey = GlobalKey();
  String? _categoryId;
  String? _groupId; // null = all
  String _query = '';
  Menu? _precached;

  void _scrollToProducts() {
    final ctx = _productsKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: TopBar(
        active: NavItem.home,
        onSearch: (q) => setState(() => _query = q.trim().toLowerCase()),
        onMenuTap: _scrollToProducts,
      ),
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
          final category = menu.categories.firstWhere(
            (c) => c.definition.id == _categoryId,
            orElse: () => menu.categories.first,
          );
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
    final groups = [
      for (final g in category.definition.productGroups)
        if (category.products.any((p) => p.groupId == g.id)) g,
    ];
    final products = [
      for (final p in category.products)
        if ((_groupId == null || p.groupId == _groupId) && _matches(p, menu)) p,
    ];
    final featured = category.products.firstOrNull;

    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.maxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Hero(
                featured: featured == null
                    ? null
                    : ProductPreview(
                        menu: menu,
                        definition: category.definition,
                        product: featured,
                      ),
                onOrder: _scrollToProducts,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 8),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _CategoryPill(
                      categories: menu.categories,
                      selected: category,
                      onSelected: (id) => setState(() {
                        _categoryId = id;
                        _groupId = null;
                      }),
                    ),
                    if (groups.isNotEmpty) ...[
                      _GroupChip(
                        label: AppStrings.allGroups,
                        icon: Icons.grid_view_rounded,
                        selected: _groupId == null,
                        onTap: () => setState(() => _groupId = null),
                      ),
                      for (final g in groups)
                        _GroupChip(
                          label: AppStrings.localized(g.name, g.names),
                          icon: Icons.local_pizza_outlined,
                          selected: _groupId == g.id,
                          onTap: () => setState(() => _groupId = g.id),
                        ),
                    ],
                  ],
                ),
              ),
              Padding(
                key: _productsKey,
                padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.ourPizzas,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _groupId = null;
                        _query = '';
                      }),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      iconAlignment: IconAlignment.end,
                      label: Text(AppStrings.viewAll),
                    ),
                  ],
                ),
              ),
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

class _Hero extends StatelessWidget {
  const _Hero({required this.featured, required this.onOrder});

  final Widget? featured;
  final VoidCallback onOrder;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppLayout.tablet;
    final gutter = AppLayout.gutter(width);
    final titleStyle = TextStyle(
      fontSize: wide ? 52 : 34,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppStrings.heroEyebrow,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w700,
            letterSpacing: 3,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 14),
        Text(AppStrings.heroTitle1, style: titleStyle),
        Text(
          AppStrings.heroTitle2,
          style: titleStyle.copyWith(color: AppColors.primary),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.heroSubtitle,
          style: const TextStyle(fontSize: 17, color: AppColors.textMuted),
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onOrder,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          ),
          icon: const Icon(Icons.arrow_forward),
          iconAlignment: IconAlignment.end,
          label: Text(
            AppStrings.orderNow,
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ],
    );
    final image = featured == null
        ? const SizedBox.shrink()
        : _Board(child: featured!);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFBF1EA), Color(0xFFF4E2D6)],
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 32),
      child: wide
          ? Row(
              children: [
                Expanded(child: text),
                SizedBox(width: 340, child: image),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: SizedBox(width: 240, child: image)),
                const SizedBox(height: 20),
                text,
              ],
            ),
    );
  }
}

/// A wooden board under the featured pizza (drawn in code; no photo yet).
class _Board extends StatelessWidget {
  const _Board({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [Color(0xFFB98552), Color(0xFF8A5A33)],
          ),
          boxShadow: AppShadows.soft,
        ),
        child: Padding(padding: const EdgeInsets.all(14), child: child),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<MenuCategory> categories;
  final MenuCategory selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.local_pizza_outlined, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            AppStrings.localized(
              selected.definition.name,
              selected.definition.names,
            ),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (categories.length > 1) ...[
            const SizedBox(width: 8),
            const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          ],
        ],
      ),
    );
    if (categories.length < 2) return pill;
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final c in categories)
          PopupMenuItem(
            value: c.definition.id,
            child: Text(
              AppStrings.localized(c.definition.name, c.definition.names),
            ),
          ),
      ],
      child: pill,
    );
  }
}

class _GroupChip extends StatelessWidget {
  const _GroupChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : AppColors.text;
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      shape: const StadiumBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: fg),
              const SizedBox(width: 10),
              Text(label, style: TextStyle(color: fg)),
            ],
          ),
        ),
      ),
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
