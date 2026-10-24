import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/strings/app_strings.dart';
import '../../menu/presentation/menu_providers.dart';
import '../../menu/presentation/product_preview.dart';
import '../domain/cart_line_view.dart';
import 'cart_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final menu = ref.watch(menuProvider);
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.cart)),
      body: menu.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(child: Text(AppStrings.menuLoadError)),
        data: (menu) {
          if (cart.lines.isEmpty) {
            return Center(child: Text(AppStrings.cartEmpty));
          }
          final views = [
            for (final l in cart.lines) CartLineView.resolve(l, menu),
          ];
          final subtotal = views.fold<int>(
            0,
            (s, v) => s + (v.available ? v.price!.total : 0),
          );
          final canCheckout = views.every((v) => v.available);
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: views.length,
                  separatorBuilder: (_, _) => const Divider(height: 24),
                  itemBuilder: (context, i) => _LineTile(
                    view: views[i],
                    preview: views[i].product == null
                        ? null
                        : ProductPreview(
                            menu: menu,
                            definition: views[i].category!.definition,
                            product: views[i].product!,
                            selection: views[i].line.selection,
                          ),
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Text(AppStrings.subtotal),
                          const Spacer(),
                          Text(
                            AppStrings.price(subtotal),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                      if (!canCheckout)
                        Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text(AppStrings.cartHasUnavailable),
                        ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: canCheckout
                            ? () => context.push('/checkout')
                            : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                        child: Text(AppStrings.checkout),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LineTile extends ConsumerWidget {
  const _LineTile({required this.view, required this.preview});

  final CartLineView view;
  final Widget? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.read(cartProvider.notifier);
    final theme = Theme.of(context);
    final line = view.line;
    final details = [
      if (view.sizeName != null) view.sizeName!,
      ...view.optionNames,
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox.square(dimension: 72, child: preview),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                view.product == null
                    ? AppStrings.productNotFound
                    : AppStrings.localized(
                        view.product!.name,
                        view.product!.names,
                      ),
                style: theme.textTheme.titleMedium,
              ),
              if (details.isNotEmpty) Text(details),
              for (final (name, qty) in view.extras)
                Text(
                  qty > 1 ? '+ $name ×$qty' : '+ $name',
                  style: TextStyle(color: theme.colorScheme.primary),
                ),
              for (final name in view.removed)
                Text(
                  '${AppStrings.without} $name',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              if (line.selection.notes.isNotEmpty)
                Text(
                  '${AppStrings.notes}: ${line.selection.notes}',
                  style: theme.textTheme.bodySmall,
                ),
              if (!view.available)
                Text(
                  AppStrings.lineUnavailable,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  _SmallButton(
                    label: '−',
                    onPressed: () => cart.setQty(line.lineId, line.qty - 1),
                  ),
                  Text('${line.qty}', style: theme.textTheme.titleMedium),
                  _SmallButton(
                    label: '+',
                    onPressed: () => cart.setQty(line.lineId, line.qty + 1),
                  ),
                  if (view.product != null)
                    TextButton(
                      onPressed: () => context.push(
                        '/product/${view.product!.id}?line=${line.lineId}',
                      ),
                      style: TextButton.styleFrom(
                        minimumSize: const Size(44, 44),
                      ),
                      child: Text(AppStrings.edit),
                    ),
                  TextButton(
                    onPressed: () => cart.remove(line.lineId),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(44, 44),
                    ),
                    child: Text(AppStrings.delete),
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          view.price == null ? '—' : AppStrings.price(view.price!.total),
          style: theme.textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: Text(label, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
