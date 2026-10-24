import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import 'cart_providers.dart';

/// App bar cart icon with the item count. FlyToCart targets it, and it
/// pulses (1 → 1.18 → 1) whenever the count grows (ANIMATIONS.md 7.3).
class CartButton extends ConsumerWidget {
  const CartButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cartProvider.select((c) => c.itemCount));
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return IconButton(
      tooltip: AppStrings.cart,
      onPressed: () {
        // Snackbars from the previous screen must not cover the cart.
        ScaffoldMessenger.of(context).clearSnackBars();
        context.push('/cart');
      },
      icon: TweenAnimationBuilder<double>(
        // A new key per count restarts the pulse; the first build is still.
        key: ValueKey(count),
        tween: Tween(begin: count == 0 || reduceMotion ? 1 : 0, end: 1),
        // Starts after the fly-in lands (Oven + Swap + most of FlyToCart).
        duration: Duration(milliseconds: reduceMotion ? 0 : 3470),
        builder: (context, t, child) {
          const start = 3250 / 3470;
          final k = t < start ? 0.0 : (t - start) / (1 - start);
          final scale =
              1 +
              0.18 *
                  Curves.easeOutBack.transform(k < 0.5 ? k * 2 : (1 - k) * 2);
          return Transform.scale(scale: scale, child: child);
        },
        child: Badge(
          isLabelVisible: count > 0,
          label: Text('$count'),
          child: const Icon(Icons.shopping_bag_outlined),
        ),
      ),
    );
  }
}
