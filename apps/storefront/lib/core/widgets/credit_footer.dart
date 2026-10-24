import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../strings/app_strings.dart';

/// Copyright line with a link to the about screen.
class CreditFooter extends StatelessWidget {
  const CreditFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: TextButton(
        onPressed: () => context.push('/about'),
        style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
        child: Text(
          AppStrings.credit,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}
