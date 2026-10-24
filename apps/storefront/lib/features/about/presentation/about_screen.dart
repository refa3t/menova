import 'package:core/core.dart';
import 'package:flutter/material.dart';

import '../../../core/strings/app_strings.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget row(String label, String value) => ListTile(
      title: Text(label),
      subtitle: SelectableText(value, textDirection: TextDirection.ltr),
    );
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.about)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(AppStrings.appTitle, style: theme.textTheme.headlineMedium),
          const SizedBox(height: 16),
          Text(AppStrings.developerInfo, style: theme.textTheme.titleLarge),
          row(
            AppStrings.developerName,
            '${DeveloperInfo.nameAr} (${DeveloperInfo.nameEn})',
          ),
          row(AppStrings.email, DeveloperInfo.email),
          row(AppStrings.phone, DeveloperInfo.phone),
          row(AppStrings.whatsapp, DeveloperInfo.whatsapp),
        ],
      ),
    );
  }
}
