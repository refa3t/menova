import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// The storefront's logo (pizza mark and name) with the panel's name under
/// it, so the admin reads as part of the same brand.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  /// One line for the phone top bar.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final name = Text(
      AppStrings.brandName,
      style: TextStyle(
        fontSize: compact ? 20 : 24,
        fontWeight: FontWeight.w800,
        color: AppColors.text,
        height: 1.1,
      ),
    );
    const panel = Text(
      AppStrings.panelName,
      style: TextStyle(fontSize: 13, color: AppColors.textMuted),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.local_pizza,
          color: AppColors.primary,
          size: compact ? 26 : 32,
        ),
        const SizedBox(width: 8),
        if (compact) ...[
          name,
          const SizedBox(width: 8),
          panel,
        ] else
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [name, panel],
          ),
      ],
    );
  }
}
