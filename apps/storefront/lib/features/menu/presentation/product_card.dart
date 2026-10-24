import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:product_builder/product_builder.dart';

import '../../../core/strings/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/presentation/cart_providers.dart';
import '../domain/menu.dart';
import 'product_preview.dart';

/// Product card (reference design): image, name, price and "Add to Cart".
/// Tapping the card opens the builder; the button adds the product as it
/// comes (defaults, first size), in one atomic step (ARC-07).
class ProductCard extends ConsumerWidget {
  const ProductCard({
    super.key,
    required this.menu,
    required this.category,
    required this.product,
  });

  final Menu menu;
  final MenuCategory category;
  final Product product;

  void _quickAdd(BuildContext context, WidgetRef ref) {
    final selection = BuilderState.open(
      definition: category.definition,
      product: product,
    ).selection;
    ref.read(cartProvider.notifier).add(selection);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '${AppStrings.addedToCart}: '
            '${AppStrings.localized(product.name, product.names)}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finalImage = menu.assets[product.imageAssetId]?.secureUrl;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/product/${product.id}'),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(AppRadii.card),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: finalImage != null
                    ? Image.network(finalImage, fit: BoxFit.contain)
                    : ProductPreview(
                        menu: menu,
                        definition: category.definition,
                        product: product,
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                AppStrings.localized(product.name, product.names),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppStrings.price(product.basePrice),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: product.isAvailable
                    ? () => _quickAdd(context, ref)
                    : null,
                icon: const Icon(Icons.shopping_cart_outlined, size: 18),
                label: Text(AppStrings.addToCart),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
