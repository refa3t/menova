import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import 'cart_providers.dart';

/// App bar cart icon with the item count. FlyToCart (P1-G04) targets it.
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((c) => c.itemCount));
    return IconButton(
      tooltip: AppStrings.cart,
      onPressed: () {
        // Snackbars from the previous screen must not cover the cart.
        ScaffoldMessenger.of(context).clearSnackBars();
        context.push('/cart');
      },
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.shopping_bag_outlined),
      ),
    );
  }
}
