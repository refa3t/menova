import 'package:flutter/material.dart';

import '../strings/app_strings.dart';
import '../theme/app_theme.dart';

/// The developer credit (CLAUDE.md section 11), built from `DeveloperInfo`.
class CreditLine extends StatelessWidget {
  const CreditLine({super.key});

  @override
  Widget build(BuildContext context) {
    return const Text(
      AppStrings.credit,
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.5),
    );
  }
}
