import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/strings/app_strings.dart';
import '../features/auth/domain/staff_access.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/orders/presentation/orders_screen.dart';

/// Staff see the orders screen only; everyone else is sent to sign in or
/// told they have no access (P1-F01).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(staffAccessProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    refreshListenable: refresh,
    initialLocation: '/splash',
    redirect: (context, state) {
      final access = ref.read(staffAccessProvider).value;
      final at = state.matchedLocation;
      // Nothing is shown until access is known.
      if (access == null) return at == '/splash' ? null : '/splash';
      return switch (access) {
        StaffAccess.signedOut => at == '/login' ? null : '/login',
        StaffAccess.denied => at == '/denied' ? null : '/denied',
        StaffAccess.granted => at == '/' ? null : '/',
      };
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const OrdersScreen()),
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
