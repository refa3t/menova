import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import 'brand_mark.dart';

/// Set by the admin shell: how a page opens the navigation panel, or null
/// when the navigation is already on screen (the wide side panel).
class AdminNavScope extends InheritedWidget {
  const AdminNavScope({super.key, required this.openNav, required super.child});

  /// Opens the sliding navigation panel on narrow screens.
  final VoidCallback? openNav;

  /// The opener of the nearest shell, or null when there is none or the
  /// side panel is shown.
  static VoidCallback? openNavOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AdminNavScope>()?.openNav;

  @override
  bool updateShouldNotify(AdminNavScope oldWidget) =>
      (oldWidget.openNav == null) != (openNav == null);
}

/// Every section's page bar. On narrow screens it is the only bar: it
/// carries the menu button that opens the navigation. A page that can go
/// back keeps its back button instead; back leads to its list, which has
/// the menu. On wide screens it is a plain [AppBar] beside the side panel.
class AdminAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AdminAppBar({super.key, this.title, this.actions, this.bottom});

  final Widget? title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;

  /// The home page's bar: the brand and the menu on narrow screens, and no
  /// bar at all beside the side panel.
  static PreferredSizeWidget? home(BuildContext context) =>
      AdminNavScope.openNavOf(context) == null
      ? null
      : const AdminAppBar(
          title: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: BrandMark(compact: true),
          ),
        );

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final openNav = AdminNavScope.openNavOf(context);
    final canGoBack = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
    return AppBar(
      leading: openNav == null || canGoBack
          ? null
          : IconButton(
              tooltip: AppStrings.openNav,
              icon: const Icon(Icons.menu),
              onPressed: openNav,
            ),
      title: title,
      actions: actions,
      bottom: bottom,
    );
  }
}
