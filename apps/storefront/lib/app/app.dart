import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/strings/app_strings.dart';
import '../core/strings/language_provider.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    AppStrings.current = language;
    return MaterialApp.router(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      // English (LTR) by default, Arabic (RTL) from the toggle.
      locale: Locale(language.code),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: buildAppTheme(),
      // Rebuild every screen when the language changes, since strings are
      // read statically. Cart and choices live in providers and survive.
      builder: (context, child) =>
          KeyedSubtree(key: ValueKey(language), child: child!),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
