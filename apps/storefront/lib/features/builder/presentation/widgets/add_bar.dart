import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';

/// Bottom bar with the add button showing the live price (P1-D03). The
/// amount counts smoothly to its new value; with reduced motion it jumps.
class AddBar extends StatelessWidget {
  const AddBar({super.key, required this.total, required this.onAdd});

  /// Total in piasters, or null when the item cannot be priced.
  final int? total;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton(
          onPressed: total == null ? null : onAdd,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: total == null
              ? const Text(AppStrings.add)
              : TweenAnimationBuilder<double>(
                  tween: Tween(end: total!.toDouble()),
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => Text(
                    '${AppStrings.add} · ${AppStrings.price(value.round())}',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
