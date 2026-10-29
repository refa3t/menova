import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/strings/app_strings.dart';
import '../features/auth/domain/admin_access.dart';
import '../features/auth/presentation/auth_providers.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/home/presentation/home_screen.dart';

/// Only the owner and menu managers get in (P3-01); everyone else is sent to
/// sign in or told they have no access.
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
        Granted() =>
          at == '/splash' || at == '/login' || at == '/denied' ? '/' : null,
      };
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
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
