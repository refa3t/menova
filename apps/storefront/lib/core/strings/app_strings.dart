import 'package:core/core.dart';

/// All user-facing Arabic strings live here (no scattered literals).
abstract final class AppStrings {
  static const appTitle = 'منوفا';
  static const menuEmpty = 'لا توجد أقسام متاحة حالياً';
  static const categoryEmpty = 'لا توجد منتجات في هذا القسم حالياً';
  static const menuLoadError = 'تعذّر تحميل المنيو';
  static const retry = 'إعادة المحاولة';
  static const productNotFound = 'المنتج غير متاح';
  static const maxQtyReached = 'وصلت للحد الأقصى لهذا المكوّن';
  static const reset = 'إعادة الضبط';
  static const ingredients = 'المكونات';
  static const quantity = 'الكمية';
  static const notes = 'ملاحظات';
  static const notesHint = 'مثال: بدون بصل زيادة، تسوية زيادة';
  static const notRemovable = 'هذا المكوّن أساسي ولا يمكن إزالته';
  static const unavailable = 'هذا المكوّن غير متوفر حالياً';
  static const notAllowed = 'هذا الاختيار غير متاح لهذا المنتج';
  static const add = 'إضافة';
  static const remove = 'إزالة';
  static const about = 'عن التطبيق';
  static const developerInfo = 'معلومات المطور';
  static const developerName = 'المطور';
  static const email = 'البريد الإلكتروني';
  static const phone = 'الهاتف';
  static const whatsapp = 'واتساب';
  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.phone}';

  /// Display-only formatting of an amount in piasters as EGP.
  static String price(int piasters) {
    final pounds = piasters / 100;
    final text = pounds == pounds.roundToDouble()
        ? pounds.toStringAsFixed(0)
        : pounds.toStringAsFixed(2);
    return '$text ج.م';
  }

  static String priceFrom(int piasters) => 'يبدأ من ${price(piasters)}';
}
