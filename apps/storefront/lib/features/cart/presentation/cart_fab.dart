import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../menu/domain/menu.dart';
import '../domain/cart_line_view.dart';
import 'cart_providers.dart';

/// Floating cart summary (HOME_SCREEN.md 2.10): item count and live total,
/// opens the cart; hidden while the cart is empty.
class CartFab extends ConsumerWidget {
  const CartFab({super.key, required this.menu});

  final Menu menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    if (cart.lines.isEmpty) return const SizedBox.shrink();
    final total = cart.lines.fold<int>(
      0,
      (s, l) => s + (CartLineView.resolve(l, menu).price?.total ?? 0),
    );
    return FloatingActionButton.extended(
      onPressed: () => context.push('/cart'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: const StadiumBorder(),
      icon: Badge(
        label: Text('${cart.itemCount}'),
        backgroundColor: Colors.white,
        textColor: AppColors.primary,
        child: const Icon(Icons.shopping_bag_outlined),
      ),
      label: Text(
        '${AppStrings.viewCart} · ${AppStrings.price(total)}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}
