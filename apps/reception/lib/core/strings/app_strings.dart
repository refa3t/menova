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
  static const ordersLoadError = 'تعذّر تحميل الطلبات';
  static const enableSound = 'تفعيل التنبيه الصوتي';
  static const soundOn = 'التنبيه مفعّل';
  static const orderNotes = 'ملاحظات الطلب';
  static const notes = 'ملاحظات';
  static const total = 'الإجمالي';
  static const includes = 'يشمل';
  static const without = 'بدون';

  static String shortReference(String id) => id.length <= 8
      ? id.toUpperCase()
      : id.substring(id.length - 8).toUpperCase();

  static String price(int piasters) {
    final p = piasters / 100;
    return '${p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(2)} ج.م';
  }

  static String fulfillment(Fulfillment f) => switch (f) {
    Fulfillment.pickup => 'استلام',
    Fulfillment.delivery => 'توصيل',
  };

  static String orderStatus(OrderStatus s) => switch (s) {
    OrderStatus.newOrder => 'جديد',
    OrderStatus.accepted => 'مقبول',
    OrderStatus.preparing => 'قيد التحضير',
    OrderStatus.ready => 'جاهز',
    OrderStatus.outForDelivery => 'خرج للتوصيل',
    OrderStatus.completed => 'مكتمل',
    OrderStatus.cancelled => 'ملغي',
  };

  static String paymentStatus(PaymentStatus s) => switch (s) {
    PaymentStatus.unpaid => 'غير مدفوع',
    PaymentStatus.paid => 'مدفوع',
    PaymentStatus.refunded => 'مسترد',
  };

  static const printTicket = 'تذكرة المطبخ';
  static const print = 'طباعة';
  static const printAgain = 'طباعة مرة أخرى';
  static const orderNotFound = 'الطلب غير موجود';

  static const priceUnverifiable =
      'تعذّر التحقق من السعر: منتج أو اختيار لم يعد معروفاً. راجع الطلب';
  static String priceMismatch(int computed) =>
      'السعر لا يطابق الحساب: المحسوب ${price(computed)}. راجع قبل القبول';

  static const subtotal = 'المنتجات';
  static const deliveryFee = 'رسوم التوصيل';
  static const openMap = 'الموقع على الخريطة';
  static String distance(int meters) =>
      '${(meters / 1000).toStringAsFixed(1)} كم بالطريق';
  static String deliveryMismatch(int? expected, int meters) => expected == null
      ? 'المسافة الفعلية ${distance(meters)} خارج نطاق التوصيل. راجع قبل القبول'
      : 'رسوم التوصيل لا تطابق المسافة الفعلية (${distance(meters)}): '
            'المحسوب ${price(expected)}. راجع قبل القبول';
  static const deliveryUnverified = 'تعذّر التحقق من مسافة التوصيل الآن';

  static const actionFailed = 'تعذّر تنفيذ الإجراء، حاول مرة أخرى';
  static const cancelOrder = 'إلغاء الطلب';
  static const cancelReason = 'سبب الإلغاء';
  static const confirmCancel = 'تأكيد الإلغاء';
  static const back = 'رجوع';

  static String actionFor(OrderStatus s) => switch (s) {
    OrderStatus.accepted => 'قبول',
    OrderStatus.preparing => 'بدء التحضير',
    OrderStatus.ready => 'جاهز',
    OrderStatus.outForDelivery => 'خرج للتوصيل',
    OrderStatus.completed => 'تم التسليم',
    OrderStatus.cancelled => 'إلغاء',
    OrderStatus.newOrder => 'جديد',
  };

  static String markPayment(PaymentStatus p) => switch (p) {
    PaymentStatus.paid => 'تم الدفع',
    PaymentStatus.refunded => 'استرداد',
    PaymentStatus.unpaid => 'غير مدفوع',
  };

  static const noAccess = 'ليس لديك صلاحية لدخول لوحة الطلبات';
  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.email} · ${DeveloperInfo.phone}';
}
