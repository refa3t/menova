import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.imageUrl});

  final Product product;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: imageUrl == null
                  ? const Icon(Icons.local_pizza_outlined, size: 64)
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.broken_image_outlined, size: 48),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.priceFrom(product.basePrice),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
