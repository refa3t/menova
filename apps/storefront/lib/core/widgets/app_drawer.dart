import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';
import 'top_bar.dart';

/// Navigation for narrow screens (HOME_SCREEN.md 2.2): the header links in
/// a side drawer.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, this.active, this.onMenuTap});

  final NavItem? active;
  final VoidCallback? onMenuTap;

  @override
  Widget build(BuildContext context) {
    void go(VoidCallback action) {
      Navigator.of(context).pop();
      action();
    }

    Widget item(NavItem i, IconData icon, String label, VoidCallback onTap) =>
        ListTile(
          leading: Icon(icon, color: i == active ? AppColors.primary : null),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: i == active ? FontWeight.w700 : FontWeight.w500,
              color: i == active ? AppColors.primary : AppColors.text,
            ),
          ),
          minTileHeight: 52,
          onTap: () => go(onTap),
        );

    return Drawer(
      backgroundColor: AppColors.page,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              leading: const Icon(Icons.local_pizza, color: AppColors.primary),
              title: Text(
                AppStrings.appTitle,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Divider(),
            item(
              NavItem.home,
              Icons.home_outlined,
              AppStrings.navHome,
              () => context.go('/'),
            ),
            item(
              NavItem.menu,
              Icons.restaurant_menu,
              AppStrings.navMenu,
              onMenuTap ?? () => context.go('/'),
            ),
            item(
              NavItem.about,
              Icons.info_outline,
              AppStrings.navAbout,
              () => context.push('/about'),
            ),
            item(
              NavItem.contact,
              Icons.call_outlined,
              AppStrings.navContact,
              () => context.push('/about'),
            ),
            ListTile(
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(AppStrings.cart),
              minTileHeight: 52,
              onTap: () => go(() => context.push('/cart')),
            ),
          ],
        ),
      ),
    );
  }
}
