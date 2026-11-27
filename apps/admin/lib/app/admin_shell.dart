import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/strings/app_strings.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/admin_app_bar.dart';
import '../core/widgets/brand_mark.dart';
import '../core/widgets/credit_line.dart';
import '../features/auth/domain/admin_access.dart';
import '../features/auth/presentation/auth_providers.dart';
import 'area_icons.dart';
import 'area_routes.dart';

/// The section that [location] belongs to, or null for the home page.
AdminArea? areaAt(String location) {
  for (final e in areaRoutes.entries) {
    if (location == e.value || location.startsWith('${e.value}/')) {
      return e.key;
    }
  }
  return null;
}

/// The frame around every section: the navigation (fixed at the side on
/// wide screens, a sliding panel on phones and tablets) with only the
/// sections the role manages, the signed-in user, sign out and the
/// developer credit. Each section keeps its own page bar ([AdminAppBar]);
/// on narrow screens that bar carries the menu button, so there is one bar.
class AdminShell extends ConsumerWidget {
  const AdminShell({
    super.key,
    required this.location,
    required this.child,
    this.onSignOut,
  });

  /// The current path, to highlight its section.
  final String location;
  final Widget child;

  /// Defaults to signing out of Firebase.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider).value;
    // The router only opens the shell for a granted admin.
    if (access is! Granted) return child;
    final signOut = onSignOut ?? () => FirebaseAuth.instance.signOut();
    final wide = MediaQuery.sizeOf(context).width >= AppLayout.sideNav;

    if (wide) {
      return Material(
        color: AppColors.page,
        child: Row(
          children: [
            SizedBox(
              width: AppLayout.sideNavWidth,
              child: _NavPanel(
                access: access,
                current: location,
                onSignOut: signOut,
                onOpen: (route) => context.go(route),
              ),
            ),
            const VerticalDivider(width: 1, color: AppColors.border),
            Expanded(child: AdminNavScope(openNav: null, child: child)),
          ],
        ),
      );
    }

    void openNav() => showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, _, _) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          width: AppLayout.sideNavWidth + 24,
          height: double.infinity,
          child: Material(
            color: AppColors.card,
            elevation: 8,
            child: _NavPanel(
              access: access,
              current: location,
              onSignOut: () {
                Navigator.of(dialogContext).pop();
                signOut();
              },
              onOpen: (route) {
                Navigator.of(dialogContext).pop();
                context.go(route);
              },
            ),
          ),
        ),
      ),
      transitionBuilder: (context, animation, _, child) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return SlideTransition(
          position: Tween(
            begin: Offset(rtl ? 1 : -1, 0),
            end: Offset.zero,
          ).animate(curve),
          child: child,
        );
      },
    );

    // No bar of its own: each page's bar carries the menu button.
    return Material(
      color: AppColors.page,
      child: AdminNavScope(openNav: openNav, child: child),
    );
  }
}

class _NavPanel extends StatelessWidget {
  const _NavPanel({
    required this.access,
    required this.current,
    required this.onOpen,
    required this.onSignOut,
  });

  final Granted access;
  final String current;
  final ValueChanged<String> onOpen;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final here = areaAt(current);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: BrandMark(),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: [
                _NavEntry(
                  icon: Icons.space_dashboard_outlined,
                  label: AppStrings.home,
                  selected: current == '/',
                  onTap: () => onOpen('/'),
                ),
                const Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(12, 16, 12, 6),
                  child: Text(
                    AppStrings.navTitle,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
                for (final a in AdminArea.values)
                  if (canManage(access.role, a) && areaRoutes[a] != null)
                    _NavEntry(
                      icon: areaIcon(a),
                      label: AppStrings.area(a),
                      selected: here == a,
                      onTap: () => onOpen(areaRoutes[a]!),
                    ),
              ],
            ),
          ),
          const Divider(),
          _UserBox(access: access, onSignOut: onSignOut),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: CreditLine(),
          ),
        ],
      ),
    );
  }
}

class _NavEntry extends StatelessWidget {
  const _NavEntry({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: ListTile(
        minTileHeight: 48,
        dense: true,
        selected: selected,
        selectedColor: AppColors.primary,
        selectedTileColor: AppColors.primarySoft,
        iconColor: AppColors.textMuted,
        textColor: AppColors.text,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        horizontalTitleGap: 12,
        leading: Icon(icon, size: 22),
        title: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _UserBox extends StatelessWidget {
  const _UserBox({required this.access, required this.onSignOut});

  final Granted access;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final email = access.email ?? '';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primarySoft,
                foregroundColor: AppColors.primary,
                child: Text(
                  email.isEmpty ? '؟' : email.characters.first.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email.isEmpty ? AppStrings.signedInAs : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: email.isEmpty ? null : TextDirection.ltr,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      AppStrings.role(access.role),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text(AppStrings.signOut),
          ),
        ],
      ),
    );
  }
}
