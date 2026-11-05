import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/strings/app_strings.dart';
import '../features/auth/domain/admin_access.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/assets/presentation/assets_screen.dart';
import '../features/audit/presentation/audit_screen.dart';
import '../features/catalog/presentation/catalog_check_screen.dart';
import '../features/catalog/presentation/categories_screen.dart';
import '../features/catalog/presentation/ingredient_edit_screen.dart';
import '../features/catalog/presentation/ingredients_screen.dart';
import '../features/catalog/presentation/product_edit_screen.dart';
import '../features/catalog/presentation/products_screen.dart';
import '../features/catalog/presentation/settings_screen.dart';
import '../features/drafts/presentation/drafts_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/offers/data/offers_providers.dart';
import '../features/offers/presentation/offer_edit_screen.dart';
import '../features/offers/presentation/offers_screen.dart';
import '../features/reports/presentation/reports_screen.dart';
import 'area_routes.dart';

/// Only the owner and menu managers get in (P3-01); everyone else is sent to
/// sign in or told they have no access. Each role only opens its sections.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(adminAccessProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/splash',
    redirect: (context, state) {
      final access = ref.read(adminAccessProvider).value;
      final at = state.matchedLocation;
      // Nothing is shown until access is known.
      if (access == null) return at == '/splash' ? null : '/splash';
      return switch (access) {
        SignedOut() => at == '/login' ? null : '/login',
        Denied() => at == '/denied' ? null : '/denied',
        Granted(:final role) =>
          at == '/splash' ||
                  at == '/login' ||
                  at == '/denied' ||
                  !mayOpen(role, at)
              ? '/'
              : null,
      };
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(path: '/audit', builder: (context, state) => const AuditScreen()),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/drafts',
        builder: (context, state) => const DraftsScreen(),
      ),
      GoRoute(
        path: '/offers',
        builder: (context, state) => const OffersScreen(),
      ),
      GoRoute(
        path: '/offers/new',
        builder: (context, state) => OfferEditScreen(
          list: state.uri.queryParameters['coupon'] == '1'
              ? OfferList.coupons
              : OfferList.auto,
        ),
      ),
      GoRoute(
        path: '/offers/auto/:id',
        builder: (context, state) => OfferEditScreen(
          list: OfferList.auto,
          id: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/offers/coupon/:id',
        builder: (context, state) => OfferEditScreen(
          list: OfferList.coupons,
          id: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/check',
        builder: (context, state) => const CatalogCheckScreen(),
      ),
      GoRoute(
        path: '/categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/assets',
        builder: (context, state) => const AssetsScreen(),
      ),
      GoRoute(
        path: '/ingredients',
        builder: (context, state) => const IngredientsScreen(),
      ),
      GoRoute(
        path: '/ingredients/:id',
        builder: (context, state) =>
            IngredientEditScreen(ingredientId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/products/new',
        builder: (context, state) => ProductEditScreen(
          categoryId: state.uri.queryParameters['category'],
        ),
      ),
      GoRoute(
        path: '/products/:id',
        builder: (context, state) =>
            ProductEditScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/denied', builder: (context, state) => const _Denied()),
    ],
  );
});

class _Denied extends StatelessWidget {
  const _Denied();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(AppStrings.noAccess),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: FirebaseAuth.instance.signOut,
              child: const Text(AppStrings.signOut),
            ),
          ],
        ),
      ),
    );
  }
}
