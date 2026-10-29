import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../auth/domain/admin_access.dart';
import '../../auth/presentation/auth_providers.dart';

/// The admin home: who is signed in and the sections their role may manage
/// (P3-01). Each section opens once its task is built.
class HomeScreen extends ConsumerWidget {
  /// Sections that are built, by route.
  static const _routes = {
    AdminArea.products: '/products',
    AdminArea.ingredients: '/ingredients',
  };

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
      appBar: AppBar(
        title: const Text(AppStrings.appTitle),
        actions: [
          TextButton(
            onPressed: FirebaseAuth.instance.signOut,
            child: const Text(AppStrings.signOut),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${AppStrings.welcome} ${access.email ?? ''}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text('${AppStrings.yourRole}: ${AppStrings.role(access.role)}'),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final a in areas)
                SizedBox(
                  width: 260,
                  child: Card(
                    child: ListTile(
                      minTileHeight: 64,
                      title: Text(AppStrings.area(a)),
                      subtitle: _routes.containsKey(a)
                          ? null
                          : const Text(AppStrings.comingSoon),
                      enabled: _routes.containsKey(a),
                      trailing: _routes.containsKey(a)
                          ? const Icon(Icons.chevron_left)
                          : null,
                      onTap: _routes.containsKey(a)
                          ? () => context.push(_routes[a]!)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text(AppStrings.credit, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
