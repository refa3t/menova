import 'package:flutter/material.dart';

/// Design tokens (P1-A11), taken from the owner's reference designs. All
/// colours, radii and shadows live here.
abstract final class AppColors {
  static const primary = Color(0xFFA8322A);
  static const primaryDark = Color(0xFF8E2A23);
  static const page = Color(0xFFFBF6F2);
  static const surface = Color(0xFFF6EDE7);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFEFE3DC);
  static const text = Color(0xFF2E1B16);
  static const textMuted = Color(0xFF7A6660);
  static const accent = Color(0xFFC8553D);
}

abstract final class AppRadii {
  static const card = 18.0;
  static const pill = 999.0;
  static const panel = 14.0;
}

abstract final class AppShadows {
  static const soft = [
    BoxShadow(color: Color(0x14782814), blurRadius: 30, offset: Offset(0, 8)),
  ];
}

/// Max content width and breakpoints (HOME_SCREEN.md 3.3, 3.4).
abstract final class AppLayout {
  static const maxWidth = 1280.0;
  static const desktop = 1100.0;
  static const tablet = 700.0;

  static double gutter(double width) => width < tablet ? 16 : 32;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.page,
  );
  const pill = StadiumBorder();
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.page,
    // UX-01: minimum 44px touch targets.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.page,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(44, 44),
        shape: pill,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        shape: pill,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      labelStyle: const TextStyle(color: AppColors.text),
      secondaryLabelStyle: const TextStyle(color: Colors.white),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        borderSide: const BorderSide(color: AppColors.border),
      ),
    ),
  );
}
