import 'package:core/core.dart';

import '../../features/auth/domain/admin_access.dart';

/// All user-facing Arabic strings live here (no scattered literals).
abstract final class AppStrings {
  static const appTitle = 'منوفا: لوحة الإدارة';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const signIn = 'تسجيل الدخول';
  static const signingIn = 'جارٍ الدخول...';
  static const signOut = 'تسجيل الخروج';
  static const loginInvalid = 'البريد أو كلمة المرور غير صحيحة';
  static const loginTooMany = 'محاولات كثيرة، حاول بعد قليل';
  static const loginFailed = 'تعذّر تسجيل الدخول';
  static const noAccess = 'ليس لديك صلاحية الإدارة. اطلب من المالك منحك دوراً.';
  static const welcome = 'أهلاً';
  static const yourRole = 'دورك';
  static const comingSoon = 'قريباً';

  static String role(AdminRole r) => switch (r) {
    AdminRole.owner => 'المالك',
    AdminRole.menuManager => 'مدير المنيو',
  };

  static String area(AdminArea a) => switch (a) {
    AdminArea.products => 'المنتجات والأسعار',
    AdminArea.ingredients => 'المكونات وأسعار الإضافات',
    AdminArea.assets => 'الصور',
    AdminArea.categories => 'الأقسام: الظهور والترتيب',
    AdminArea.settings => 'إعدادات المطعم والتوصيل',
    AdminArea.reports => 'التقارير والمبيعات',
    AdminArea.audit => 'سجل التعديلات',
  };

  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.email} · ${DeveloperInfo.phone}';
}
