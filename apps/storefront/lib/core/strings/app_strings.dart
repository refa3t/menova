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
  static const add = 'إضافة';
  static const remove = 'إزالة';

  /// Display-only formatting of an amount in piasters as EGP.
  static String priceFrom(int piasters) {
    final pounds = piasters / 100;
    final text = pounds == pounds.roundToDouble()
        ? pounds.toStringAsFixed(0)
        : pounds.toStringAsFixed(2);
    return 'يبدأ من $text ج.م';
  }
}
