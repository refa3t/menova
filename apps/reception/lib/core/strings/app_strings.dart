import 'package:core/core.dart';

/// All user-facing Arabic strings live here (no scattered literals).
abstract final class AppStrings {
  static const appTitle = 'منوفا: استقبال الطلبات';
  static const orders = 'الطلبات';
  static const noOrders = 'لا توجد طلبات حالياً';
  static const email = 'البريد الإلكتروني';
  static const password = 'كلمة المرور';
  static const signIn = 'تسجيل الدخول';
  static const signingIn = 'جارٍ الدخول...';
  static const signOut = 'تسجيل الخروج';
  static const loginInvalid = 'البريد أو كلمة المرور غير صحيحة';
  static const loginTooMany = 'محاولات كثيرة، حاول بعد قليل';
  static const loginFailed = 'تعذّر تسجيل الدخول';
  static const noAccess = 'ليس لديك صلاحية لدخول لوحة الطلبات';
  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.email} · ${DeveloperInfo.phone}';
}
