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

  // Products (P3-02).
  static const products = 'المنتجات';
  static const newProduct = 'منتج جديد';
  static const editProduct = 'تعديل المنتج';
  static const searchProducts = 'ابحث بالاسم';
  static const allCategories = 'كل الأقسام';
  static const available = 'متاح';
  static const unavailable = 'غير متاح';
  static const nameAr = 'الاسم بالعربي';
  static const nameEn = 'الاسم بالإنجليزي';
  static const description = 'الوصف';
  static const basePrice = 'السعر الأساسي (ج.م)';
  static const basePriceHint = 'يشمل كل المكونات الافتراضية';
  static const sizePrices = 'فرق السعر لكل حجم (ج.م)';
  static const optionPrices = 'سعر الخيارات (ج.م)';
  static const group = 'القسم الفرعي';
  static const noGroup = 'بدون';
  static const defaults = 'المكونات الافتراضية';
  static const qty = 'الكمية';
  static const removable = 'يمكن حذفه';
  static const addIngredient = 'أضف مكوّناً';
  static const displayOrder = 'ترتيب العرض';
  static const category = 'القسم';
  static const save = 'حفظ';
  static const saving = 'جارٍ الحفظ...';
  static const saved = 'تم الحفظ';
  static const saveFailed = 'تعذّر الحفظ. تحقق من صلاحيتك والاتصال';
  static const fixErrors = 'صحّح ما يلي قبل الحفظ:';
  static const loadError = 'تعذّر التحميل';
  static const invalidMoney = 'رقم غير صحيح';
  static const back = 'رجوع';
  static const open = 'فتح';

  /// Piasters as pounds for an input field (no currency sign).
  static String egp(int piasters) {
    final p = piasters / 100;
    return p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2);
  }

  static String price(int piasters) => '${egp(piasters)} ج.م';

  /// Pounds typed by the admin (Arabic or Latin digits) to piasters; null if
  /// it is not a number with at most two decimals.
  static int? parseEgp(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final latin = text.trim().split('').map((c) {
      final i = arabic.indexOf(c);
      return i >= 0 ? '$i' : (c == '٫' || c == ',' ? '.' : c);
    }).join();
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(latin)) return null;
    return (double.parse(latin) * 100).round();
  }

  /// Arabic label for a validator path (`basePrice`, `defaults[0].qty`...).
  static String issue(String path) {
    final key = path.split(RegExp(r'[.\[]')).first;
    return switch (key) {
      'name' || 'names' => 'الاسم مطلوب',
      'basePrice' => 'السعر الأساسي يجب أن يكون أكبر من صفر',
      'sizeDeltas' => 'فرق سعر الحجم غير صحيح',
      'optionDeltas' => 'سعر الخيار غير صحيح',
      'defaults' => 'المكونات الافتراضية: مكوّن مكرر أو غير مسموح أو كمية صفر',
      'groupId' => 'القسم الفرعي غير موجود',
      'categoryId' => 'القسم لا يطابق المنتج',
      'displayOrder' => 'ترتيب العرض غير صحيح',
      _ => path,
    };
  }

  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.email} · ${DeveloperInfo.phone}';
}
