import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/builder/presentation/builder_prototype_screen.dart';
import '../features/menu/presentation/menu_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) =>
            BuilderPrototypeScreen(productId: state.pathParameters['id']!),
      ),
    ],
  );
});
