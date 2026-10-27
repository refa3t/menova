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
import 'product_preview.dart';

/// Home page (reference design): header, hero, the menu's categories, the
/// features and the footer. A category opens its own page with its groups
/// and products (owner request). Generic over categories.
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  final _categoriesKey = GlobalKey();
  Menu? _precached;

  void _scrollToCategories() {
    final ctx = _categoriesKey.currentContext;
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
      drawer: AppDrawer(active: NavItem.home, onMenuTap: _scrollToCategories),
      floatingActionButton: menu.hasValue
          ? CartFab(menu: menu.requireValue)
          : null,
      appBar: TopBar(active: NavItem.home, onMenuTap: _scrollToCategories),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            MenuErrorView(onRetry: () => ref.invalidate(menuProvider)),
        data: (menu) {
          if (!identical(_precached, menu)) {
            _precached = menu;
            precacheMenuImages(context, menu);
          }
          if (menu.categories.isEmpty) {
            return Center(child: Text(AppStrings.menuEmpty));
          }
          return _body(context, menu);
        },
      ),
    );
  }

  Widget _body(BuildContext context, Menu menu) {
    final width = MediaQuery.sizeOf(context).width;
    final gutter = AppLayout.gutter(width);
    final first = menu.categories.first;
    final featured = first.products.firstOrNull;

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
                        definition: first.definition,
                        product: featured,
                      ),
                // One category: go straight to it; several: show them.
                onOrder: menu.categories.length == 1
                    ? () => context.push('/category/${first.definition.id}')
                    : _scrollToCategories,
              ),
              Padding(
                key: _categoriesKey,
                padding: EdgeInsets.fromLTRB(gutter, 32, gutter, 16),
                child: Text(
                  AppStrings.ourMenu,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: gutter),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 300,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 18,
                    childAspectRatio: 0.82,
                  ),
                  itemCount: menu.categories.length,
                  itemBuilder: (context, i) =>
                      _CategoryCard(menu: menu, category: menu.categories[i]),
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

/// A category on the home page: a preview, its name, how many products and
/// the lowest price. Opens the category page.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.menu, required this.category});

  final Menu menu;
  final MenuCategory category;

  @override
  Widget build(BuildContext context) {
    final def = category.definition;
    final featured = category.products.firstOrNull;
    final prices = [for (final p in category.products) p.basePrice];
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/category/${def.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: featured == null
                      ? const Icon(Icons.restaurant_menu, size: 64)
                      : PreviewBoard(
                          child: ProductPreview(
                            menu: menu,
                            definition: def,
                            product: featured,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppStrings.localized(def.name, def.names),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  AppStrings.productCount(category.products.length),
                  if (prices.isNotEmpty)
                    AppStrings.priceFrom(
                      prices.reduce((a, b) => a < b ? a : b),
                    ),
                ].join(' · '),
                style: const TextStyle(color: AppColors.textMuted),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => context.push('/category/${def.id}'),
                icon: const Icon(Icons.arrow_forward, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(AppStrings.browse),
              ),
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
        : PreviewBoard(child: featured!);
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
