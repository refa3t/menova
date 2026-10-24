import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/about/presentation/about_screen.dart';
import '../features/builder/presentation/builder_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/checkout/presentation/checkout_screen.dart';
import '../features/order/presentation/order_screen.dart';
import '../features/menu/presentation/menu_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const MenuScreen()),
      GoRoute(
        path: '/order/:id',
        builder: (context, state) =>
            OrderScreen(orderId: state.pathParameters['id']!),
      ),
      GoRoute(path: '/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(path: '/about', builder: (context, state) => const AboutScreen()),
      GoRoute(
        path: '/product/:id',
        builder: (context, state) => BuilderScreen(
          productId: state.pathParameters['id']!,
          lineId: state.uri.queryParameters['line'],
        ),
      ),
    ],
  );
});
