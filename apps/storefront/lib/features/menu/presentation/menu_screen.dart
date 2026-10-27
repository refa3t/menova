import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
              SizedBox(key: _categoriesKey, height: 16),
              for (final c in menu.categories)
                _CategoryStrip(menu: menu, category: c, gutter: gutter),
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

/// A category on the home page (owner request): its name, which opens the
/// category's full menu, and a horizontal strip of its first products.
class _CategoryStrip extends StatefulWidget {
  const _CategoryStrip({
    required this.menu,
    required this.category,
    required this.gutter,
  });

  /// How many products the home strip shows before "View All".
  static const _shown = 10;

  final Menu menu;
  final MenuCategory category;
  final double gutter;

  @override
  State<_CategoryStrip> createState() => _CategoryStripState();
}

class _CategoryStripState extends State<_CategoryStrip> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final menu = widget.menu;
    final category = widget.category;
    final gutter = widget.gutter;
    final def = category.definition;
    void open() => context.push('/category/${def.id}');
    final products = category.products.take(_CategoryStrip._shown).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: open,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppStrings.localized(def.name, def.names),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          AppStrings.productCount(category.products.length),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: open,
                icon: const Icon(Icons.arrow_forward, size: 18),
                iconAlignment: IconAlignment.end,
                label: Text(AppStrings.viewAll),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 312,
          // Mouse users can drag the strip too (Flutter drags only touch by
          // default); the scrollbar shows there is more.
          child: ScrollConfiguration(
            behavior: ScrollConfiguration.of(
              context,
            ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: Scrollbar(
              controller: _controller,
              child: ListView.separated(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: gutter),
                itemCount: products.length,
                separatorBuilder: (_, _) => const SizedBox(width: 14),
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: 190,
                    child: ProductCard(
                      menu: menu,
                      category: category,
                      product: products[i],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
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
