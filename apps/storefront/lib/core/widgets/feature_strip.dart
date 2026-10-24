import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// The four-feature strip from the reference design. Wording avoids claims
/// the restaurant has not confirmed (HOME_SCREEN.md 9).
class FeatureStrip extends StatelessWidget {
  const FeatureStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.local_shipping_outlined,
        AppStrings.featureDelivery,
        AppStrings.featureDeliverySub,
      ),
      (Icons.eco_outlined, AppStrings.featureFresh, AppStrings.featureFreshSub),
      (
        Icons.payments_outlined,
        AppStrings.featurePayment,
        AppStrings.featurePaymentSub,
      ),
      (
        Icons.support_agent_outlined,
        AppStrings.featureSupport,
        AppStrings.featureSupportSub,
      ),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceAround,
        runSpacing: 16,
        spacing: 24,
        children: [
          for (final (icon, title, sub) in items)
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 180),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppColors.primary, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        sub,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
