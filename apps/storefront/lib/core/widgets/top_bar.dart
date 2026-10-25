import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/cart/presentation/cart_button.dart';
import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import 'language_button.dart';

enum NavItem { home, menu, about, contact }

/// Site header (reference design): logo, links, optional search, cart and
/// language. Links collapse on narrow screens.
class TopBar extends StatelessWidget implements PreferredSizeWidget {
  const TopBar({
    super.key,
    this.active,
    this.onSearch,
    this.cartKey,
    this.onMenuTap,
  });

  final NavItem? active;

  /// When given, a search field is shown and reports every change.
  final ValueChanged<String>? onSearch;

  /// Key of the cart icon (the fly-to-cart target).
  final Key? cartKey;

  /// Scrolls to the menu on the home page; otherwise navigates home.
  final VoidCallback? onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= AppLayout.desktop;
    final gutter = AppLayout.gutter(width);
    void go(NavItem item) => switch (item) {
      NavItem.home => context.go('/'),
      NavItem.menu => onMenuTap != null ? onMenuTap!() : context.go('/'),
      NavItem.about || NavItem.contact => context.push('/about'),
    };
    String label(NavItem i) => switch (i) {
      NavItem.home => AppStrings.navHome,
      NavItem.menu => AppStrings.navMenu,
      NavItem.about => AppStrings.navAbout,
      NavItem.contact => AppStrings.navContact,
    };

    return Material(
      color: AppColors.page,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 72,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.border)),
          ),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Row(
            children: [
              if (!wide && Scaffold.maybeOf(context)?.hasDrawer == true)
                IconButton(
                  tooltip: AppStrings.navMenu,
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_pizza,
                        color: AppColors.primary,
                        size: 30,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.appTitle,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              if (wide)
                for (final item in NavItem.values)
                  _NavLink(
                    label: label(item),
                    active: item == active,
                    onTap: () => go(item),
                  ),
              if (wide) const Spacer(),
              if (onSearch != null && width >= AppLayout.tablet)
                SizedBox(
                  width: wide ? 280 : 200,
                  height: 44,
                  child: TextField(
                    onChanged: onSearch,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      contentPadding: EdgeInsets.zero,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              CartButton(key: cartKey),
              const LanguageButton(),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatelessWidget {
  const _NavLink({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            color: active ? AppColors.primary : AppColors.text,
          ),
        ),
      ),
    );
  }
}
