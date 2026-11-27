import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/area_icons.dart';
import '../../../app/area_routes.dart';
import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';

/// The admin home (P3-01): a dashboard of the sections the signed-in role
/// may manage. The shell around it shows the user, sign out and the credit.
class HomeScreen extends ConsumerWidget {
  static const _routes = areaRoutes;

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(adminAccessProvider).value;
    if (access is! Granted) return const SizedBox.shrink();
    final areas = [
      for (final a in AdminArea.values)
        if (canManage(access.role, a)) a,
    ];
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final gutter = AppLayout.gutter(box.maxWidth);
          final inner = (box.maxWidth - 2 * gutter).clamp(0.0, 1100.0);
          const gap = 12.0;
          final columns = ((inner + gap) / (300 + gap)).floor().clamp(1, 3);
          final cardWidth = (inner - gap * (columns - 1)) / columns;
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 24),
            children: [
              Center(
                child: SizedBox(
                  width: inner,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.welcome,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (access.email case final email?)
                            Text(
                              email,
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          _RoleBadge(
                            '${AppStrings.yourRole}: '
                            '${AppStrings.role(access.role)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        AppStrings.homeIntro,
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final a in areas)
                            SizedBox(
                              width: cardWidth,
                              child: _AreaCard(
                                area: a,
                                onTap: _routes.containsKey(a)
                                    ? () => context.go(_routes[a]!)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AreaCard extends StatelessWidget {
  const _AreaCard({required this.area, required this.onTap});

  final AdminArea area;

  /// Null while the section is not built yet.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 88),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadii.panel),
                  ),
                  child: Icon(areaIcon(area), color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppStrings.area(area),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        enabled
                            ? AppStrings.areaHint(area)
                            : AppStrings.comingSoon,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
