import 'package:core/core.dart';

/// All user-facing Arabic strings live here (no scattered literals).
abstract final class AppStrings {
  static const orderTitle = 'طلبك';
  static const orderReference = 'رقم الطلب';
  static const orderStatusLabel = 'حالة الطلب';
  static const paymentStatusLabel = 'حالة الدفع';
  static const orderCancelled = 'تم إلغاء الطلب';
  static const orderNotFound = 'الطلب غير موجود';
  static const orderLoadError = 'تعذّر تحميل الطلب';

  /// Short human reference shown to the guest and the kitchen.
  static String shortReference(String id) => id.length <= 8
      ? id.toUpperCase()
      : id.substring(id.length - 8).toUpperCase();

  static String orderStatus(OrderStatus s) => switch (s) {
    OrderStatus.newOrder => 'تم استلام الطلب',
    OrderStatus.accepted => 'تم قبول الطلب',
    OrderStatus.preparing => 'جارٍ التحضير',
    OrderStatus.ready => 'جاهز',
    OrderStatus.outForDelivery => 'في الطريق إليك',
    OrderStatus.completed => 'تم التسليم',
    OrderStatus.cancelled => 'ملغي',
  };

  static String paymentStatus(PaymentStatus s) => switch (s) {
    PaymentStatus.unpaid => 'لم يُدفع',
    PaymentStatus.paid => 'مدفوع',
    PaymentStatus.refunded => 'مسترد',
  };

  static const appTitle = 'منوفا';
  static const menuEmpty = 'لا توجد أقسام متاحة حالياً';
  static const categoryEmpty = 'لا توجد منتجات في هذا القسم حالياً';
  static const menuLoadError = 'تعذّر تحميل المنيو';
  static const retry = 'إعادة المحاولة';
  static const productNotFound = 'المنتج غير متاح';
  static const maxQtyReached = 'وصلت للحد الأقصى لهذا المكوّن';
  static const reset = 'إعادة الضبط';
  static const name = 'الاسم';
  static const fulfillment = 'طريقة الاستلام';
  static const pickup = 'استلام من المطعم';
  static const delivery = 'توصيل';
  static const address = 'العنوان';
  static const orderNotes = 'ملاحظات على الطلب';
  static const paymentCash = 'الدفع نقداً عند الاستلام';
  static const confirmOrder = 'تأكيد الطلب';
  static const errorName = 'اكتب اسمك';
  static const errorPhone = 'اكتب رقم موبايل مصري صحيح (11 رقم)';
  static const errorAddress = 'اكتب عنوان التوصيل';
  static const orderingUnavailable =
      'إرسال الطلبات غير متاح بعد في النسخة التجريبية';
  static const update = 'تحديث';
  static const addedToCart = 'تمت الإضافة';
  static const preparing = 'جارٍ التحضير...';
  static const viewCart = 'عرض السلة';
  static const cart = 'السلة';
  static const cartEmpty = 'السلة فارغة';
  static const subtotal = 'الإجمالي';
  static const checkout = 'إتمام الطلب';
  static const without = 'بدون';
  static const edit = 'تعديل';
  static const delete = 'حذف';
  static const lineUnavailable = 'هذا البند لم يعد متاحاً، عدّله أو احذفه';
  static const cartHasUnavailable = 'في السلة بنود غير متاحة';
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
