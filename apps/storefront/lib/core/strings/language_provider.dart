import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/cart/presentation/cart_providers.dart';
import 'app_strings.dart';

/// The chosen display language, saved on the device. English by default.
final languageProvider = NotifierProvider<LanguageController, AppLanguage>(
  LanguageController.new,
);

class LanguageController extends Notifier<AppLanguage> {
  static const _key = 'language.v1';

  @override
  AppLanguage build() {
    final saved = ref.read(sharedPreferencesProvider).getString(_key);
    return AppLanguage.values.where((l) => l.code == saved).firstOrNull ??
        AppLanguage.en;
  }

  void toggle() {
    state = state == AppLanguage.en ? AppLanguage.ar : AppLanguage.en;
    ref.read(sharedPreferencesProvider).setString(_key, state.code);
  }
}
