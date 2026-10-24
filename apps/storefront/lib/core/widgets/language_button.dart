import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../strings/app_strings.dart';
import '../strings/language_provider.dart';

/// Switches between English and Arabic; shows the other language's name.
class LanguageButton extends ConsumerWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    return TextButton(
      onPressed: ref.read(languageProvider.notifier).toggle,
      style: TextButton.styleFrom(minimumSize: const Size(44, 44)),
      child: Text(AppStrings.languageToggle),
    );
  }
}
