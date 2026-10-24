import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';

/// Add button states (ANIMATIONS.md 6, P1-G05).
enum AddStatus { idle, busy, done }

/// Bottom bar with the add button showing the live price (P1-D03). The
/// amount counts smoothly to its new value; with reduced motion it jumps.
class AddBar extends StatelessWidget {
  const AddBar({
    super.key,
    required this.total,
    required this.onAdd,
    String? label,
    this.status = AddStatus.idle,
  }) : _label = label;

  final String? _label;

  /// Button label; defaults to "add" in the current language.
  String get label => _label ?? AppStrings.add;
  final AddStatus status;

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
        child: AnimatedSwitcher(
          duration: Duration(milliseconds: reduceMotion ? 0 : 150),
          child: switch (status) {
            AddStatus.busy => FilledButton(
              key: const ValueKey('busy'),
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: Text(AppStrings.preparing),
            ),
            AddStatus.done => FilledButton(
              key: const ValueKey('done'),
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                disabledBackgroundColor: const Color(0xFF2E7D32),
                disabledForegroundColor: Colors.white,
              ),
              child: Text('${AppStrings.addedToCart} ✓'),
            ),
            AddStatus.idle => FilledButton(
              key: const ValueKey('idle'),
              onPressed: total == null ? null : onAdd,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: total == null
                  ? Text(label)
                  : TweenAnimationBuilder<double>(
                      tween: Tween(end: total!.toDouble()),
                      duration: reduceMotion
                          ? Duration.zero
                          : const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => Text(
                        '$label · ${AppStrings.price(value.round())}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
          },
        ),
      ),
    );
  }
}
