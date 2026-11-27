import 'package:flutter/material.dart';

/// Design tokens of the admin panel. Copied from the storefront brand
/// (apps/storefront/lib/core/theme/app_theme.dart) so both sites look like
/// one product; the apps never import each other. Keep the shared values in
/// step with the storefront when the brand changes.
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

  /// Tint behind the selected navigation entry and the area icons.
  static const primarySoft = Color(0xFFF7E4E0);
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

/// Breakpoints and sizes of the panel.
abstract final class AppLayout {
  static const tablet = 700.0;

  /// From this width the navigation stays fixed at the side; below it the
  /// navigation opens as a drawer.
  static const sideNav = 1000.0;
  static const sideNavWidth = 280.0;

  /// UX-01: no touch target under 44px.
  static const minTouch = 44.0;

  static double gutter(double width) => width < tablet ? 16 : 32;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.page,
  );
  const pill = StadiumBorder();
  final panel = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadii.panel),
  );
  const minSize = Size(AppLayout.minTouch, AppLayout.minTouch);
  // Typography gives the font and colours; sizes come from the theme's
  // geometry, so styles used outside the text theme state their size.
  final text = Typography.blackMountainView.apply(
    bodyColor: AppColors.text,
    displayColor: AppColors.text,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.page,
    // UX-01: minimum 44px touch targets.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    textTheme: text,
    // Each section's own bar reads as the page header under the shell.
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.page,
      foregroundColor: AppColors.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.panel),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(
      shape: panel,
      iconColor: AppColors.textMuted,
      subtitleTextStyle: text.bodyMedium?.copyWith(
        color: AppColors.textMuted,
        fontSize: 13,
      ),
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minSize,
        shape: pill,
        textStyle: text.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minSize,
        shape: pill,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: minSize, shape: pill),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: minSize),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      shape: StadiumBorder(),
    ),
    chipTheme: ChipThemeData(
      shape: pill,
      side: const BorderSide(color: AppColors.border),
      backgroundColor: AppColors.card,
      selectedColor: AppColors.primary,
      secondarySelectedColor: AppColors.primary,
      labelStyle: text.labelLarge?.copyWith(
        fontSize: 14,
        color: AppColors.text,
      ),
      secondaryLabelStyle: text.labelLarge?.copyWith(
        fontSize: 14,
        color: Colors.white,
      ),
      checkmarkColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.primary,
      dividerColor: AppColors.border,
    ),
    drawerTheme: const DrawerThemeData(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: panel,
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
