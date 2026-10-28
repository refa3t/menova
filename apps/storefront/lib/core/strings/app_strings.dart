import 'package:core/core.dart';

/// The storefront's display language. English is the default; Arabic is
/// available from the language toggle (owner decision, amends UX-01).
enum AppLanguage {
  en('en'),
  ar('ar');

  const AppLanguage(this.code);
  final String code;

  bool get isRtl => this == ar;
}

/// All user-facing strings live here, in both languages (no scattered
/// literals). [current] is set by the app from the saved language choice.
abstract final class AppStrings {
  static AppLanguage current = AppLanguage.en;

  static String _t(String en, String ar) => current == AppLanguage.ar ? ar : en;

  /// A data name in the current language: `names[code]`, else [fallback].
  static String localized(String fallback, Map<String, String> names) =>
      names[current.code] ?? fallback;

  static String get languageToggle => _t('العربية', 'English');

  static String get orderTitle => _t('Your order', 'طلبك');
  static String get orderReference => _t('Order number', 'رقم الطلب');
  static String get orderStatusLabel => _t('Order status', 'حالة الطلب');
  static String get paymentStatusLabel => _t('Payment', 'حالة الدفع');
  static String get orderCancelled =>
      _t('This order was cancelled', 'تم إلغاء الطلب');
  static String get orderNotFound => _t('Order not found', 'الطلب غير موجود');
  static String get orderLoadError =>
      _t('Could not load the order', 'تعذّر تحميل الطلب');

  /// Short human reference shown to the guest and the kitchen.
  static String shortReference(String id) => id.length <= 8
      ? id.toUpperCase()
      : id.substring(id.length - 8).toUpperCase();

  static String orderStatus(OrderStatus s) => switch (s) {
    OrderStatus.newOrder => _t('Order received', 'تم استلام الطلب'),
    OrderStatus.accepted => _t('Accepted', 'تم قبول الطلب'),
    OrderStatus.preparing => _t('Preparing', 'جارٍ التحضير'),
    OrderStatus.ready => _t('Ready', 'جاهز'),
    OrderStatus.outForDelivery => _t('On the way', 'في الطريق إليك'),
    OrderStatus.completed => _t('Delivered', 'تم التسليم'),
    OrderStatus.cancelled => _t('Cancelled', 'ملغي'),
  };

  static String paymentStatus(PaymentStatus s) => switch (s) {
    PaymentStatus.unpaid => _t('Unpaid', 'لم يُدفع'),
    PaymentStatus.paid => _t('Paid', 'مدفوع'),
    PaymentStatus.refunded => _t('Refunded', 'مسترد'),
  };

  static String get appTitle => _t('Menova', 'منوفا');
  static String get navHome => _t('Home', 'الرئيسية');
  static String get navMenu => _t('Menu', 'المنيو');
  static String get navAbout => _t('About', 'عن منوفا');
  static String get navContact => _t('Contact', 'تواصل معنا');
  static String get searchHint =>
      _t('Search the menu...', 'ابحث في المنيو...');
  static String get heroEyebrow =>
      _t('FRESH INGREDIENTS  •  BETTER PIZZA', 'مكونات طازجة  •  بيتزا أفضل');
  static String get heroTitle1 => _t('Real Pizza,', 'بيتزا حقيقية،');
  static String get heroTitle2 => _t('Real Happiness', 'سعادة حقيقية');
  static String get heroSubtitle => _t(
    'Made with the freshest ingredients, just for you.',
    'محضّرة بأطزج المكونات، خصيصاً لك.',
  );
  static String get orderNow => _t('Order Now', 'اطلب الآن');
  static String get categoryNotFound =>
      _t('This section is not available', 'هذا القسم غير متاح');
  static String productCount(int n) => _t('$n items', '$n صنف');
  static String get viewAll => _t('View All', 'عرض الكل');
  static String get addToCart => _t('Add to Cart', 'أضف للسلة');
  static String get backToMenu => _t('Back to Menu', 'العودة للمنيو');
  static String get size => _t('Size', 'الحجم');
  static String get noResults =>
      _t('No pizzas match your search', 'لا توجد نتائج مطابقة');
  static String get featureDelivery => _t('Fast Delivery', 'توصيل سريع');
  static String get featureDeliverySub =>
      _t('To your door in no time', 'لباب بيتك في أسرع وقت');
  static String get featureFresh => _t('Fresh Ingredients', 'مكونات طازجة');
  static String get featureFreshSub =>
      _t('Only the best for you', 'الأفضل فقط لك');
  static String get featurePayment => _t('Easy Payment', 'دفع سهل');
  static String get featurePaymentSub =>
      _t('Cash on delivery or pickup', 'نقداً عند الاستلام');
  static String get featureSupport => _t('Friendly Support', 'دعم ودود');
  static String get featureSupportSub =>
      _t('We are always here for you', 'دائماً في خدمتك');
  static String get notesPlaceholder =>
      _t('Add any special requests...', 'أضف أي طلبات خاصة...');
  static String plusPrice(int piasters) => '+ ${price(piasters)}';
  static String get menuEmpty =>
      _t('No categories available right now', 'لا توجد أقسام متاحة حالياً');
  static String get categoryEmpty => _t(
    'No products in this category right now',
    'لا توجد منتجات في هذا القسم حالياً',
  );
  static String get allGroups => _t('All', 'الكل');
  static String get menuLoadError =>
      _t('Could not load the menu', 'تعذّر تحميل المنيو');
  static String get retry => _t('Try again', 'إعادة المحاولة');
  static String get productNotFound =>
      _t('This product is not available', 'المنتج غير متاح');
  static String get maxQtyReached =>
      _t('Maximum reached for this topping', 'وصلت للحد الأقصى لهذا المكوّن');
  static String get reset => _t('Reset', 'إعادة الضبط');
  static String get name => _t('Name', 'الاسم');
  static String get fulfillment => _t('How do you want it?', 'طريقة الاستلام');
  static String get pickup => _t('Pick up', 'استلام من المطعم');
  static String get delivery => _t('Delivery', 'توصيل');
  static String get address => _t('Address', 'العنوان');
  static String get useMyLocation => _t('Use my location', 'حدّد موقعي');
  static String get locating =>
      _t('Finding your location...', 'جارٍ تحديد موقعك...');
  static String get relocate => _t('Update location', 'تحديث الموقع');
  static String get deliveryFee => _t('Delivery fee', 'رسوم التوصيل');
  static String get orderTotal => _t('Total', 'الإجمالي');
  static String deliveryDistance(int meters) {
    final km = (meters / 1000).toStringAsFixed(1);
    return _t('$km km by road', '$km كم بالطريق');
  }

  static String get deliveryNeedsLocation => _t(
    'Share your location to price the delivery',
    'شارك موقعك لحساب رسوم التوصيل',
  );
  static String get locationDenied => _t(
    'Location permission was denied. Allow it in the browser and try again.',
    'تم رفض إذن الموقع. اسمح به من المتصفح وأعد المحاولة',
  );
  static String get locationUnavailable => _t(
    'Could not get your location. Try again.',
    'تعذّر تحديد موقعك. أعد المحاولة',
  );
  static String get routeFailed => _t(
    'Could not calculate the delivery distance. Try again.',
    'تعذّر حساب مسافة التوصيل. أعد المحاولة',
  );
  static String get outOfRange => _t(
    'Sorry, your location is outside our delivery area.',
    'عذراً، موقعك خارج نطاق التوصيل',
  );
  static String get orderNotes => _t('Order notes', 'ملاحظات على الطلب');
  static String get paymentCash =>
      _t('Cash on delivery or pickup', 'الدفع نقداً عند الاستلام');
  static String get confirmOrder => _t('Place order', 'تأكيد الطلب');
  static String get errorName => _t('Enter your name', 'اكتب اسمك');
  static String get errorPhone => _t(
    'Enter a valid Egyptian mobile number (11 digits)',
    'اكتب رقم موبايل مصري صحيح (11 رقم)',
  );
  static String get errorAddress =>
      _t('Enter the delivery address', 'اكتب عنوان التوصيل');
  static String get sendingOrder =>
      _t('Sending your order...', 'جارٍ إرسال الطلب...');
  static String get checkingOrder =>
      _t('Checking your order...', 'جارٍ التأكد من الطلب...');
  static String get pendingSend => _t(
    'Waiting to send: we could not confirm your order. Try again; it will '
        'not be duplicated.',
    'بانتظار الإرسال: لم يتأكد وصول الطلب. أعد المحاولة، ولن يتكرر الطلب',
  );
  static String get retrySend => _t('Try again', 'إعادة المحاولة');
  static String get orderConflict => _t(
    'We could not confirm the order, please try again',
    'تعذّر تأكيد الطلب، حاول مرة أخرى',
  );
  static String get pricesChanged =>
      _t('Some prices changed', 'تغيّرت بعض الأسعار');
  static String get pricesChangedBody => _t(
    'The price or availability of some items changed since you opened '
        'the cart:',
    'تغيّرت أسعار أو توفر بعض البنود منذ فتحت السلة:',
  );
  static String get noLongerAvailable =>
      _t('no longer available', 'لم يعد متاحاً');
  static String get acceptNewPrices =>
      _t('Accept the new prices', 'موافق على الأسعار الجديدة');
  static String get backToCart => _t('Back to cart', 'العودة للسلة');
  static String get update => _t('Update', 'تحديث');
  static String get addedToCart => _t('Added', 'تمت الإضافة');
  static String get preparing => _t('Preparing...', 'جارٍ التحضير...');
  static String get viewCart => _t('View cart', 'عرض السلة');
  static String get cart => _t('Cart', 'السلة');
  static String get cartEmpty => _t('Your cart is empty', 'السلة فارغة');
  static String get subtotal => _t('Total', 'الإجمالي');
  static String get checkout => _t('Checkout', 'إتمام الطلب');
  static String get without => _t('No', 'بدون');
  static String get edit => _t('Edit', 'تعديل');
  static String get delete => _t('Remove', 'حذف');
  static String get lineUnavailable => _t(
    'This item is no longer available. Edit or remove it.',
    'هذا البند لم يعد متاحاً، عدّله أو احذفه',
  );
  static String get cartHasUnavailable =>
      _t('Your cart has unavailable items', 'في السلة بنود غير متاحة');
  static String get ingredients => _t('Toppings', 'المكونات');
  static String get quantity => _t('Quantity', 'الكمية');
  static String get notes => _t('Notes', 'ملاحظات');
  static String get notesHint =>
      _t('e.g. extra crispy, light sauce', 'مثال: بدون بصل زيادة، تسوية زيادة');
  static String get notRemovable => _t(
    'This topping is part of the recipe and cannot be removed',
    'هذا المكوّن أساسي ولا يمكن إزالته',
  );
  static String get unavailable => _t(
    'This topping is not available right now',
    'هذا المكوّن غير متوفر حالياً',
  );
  static String get notAllowed => _t(
    'This choice is not available for this product',
    'هذا الاختيار غير متاح لهذا المنتج',
  );
  static String get add => _t('Add', 'إضافة');
  static String get remove => _t('Remove', 'إزالة');
  static String get about => _t('About', 'عن التطبيق');
  static String get developerInfo => _t('Developer', 'معلومات المطور');
  static String get developerName => _t('Developer', 'المطور');
  static String get email => _t('Email', 'البريد الإلكتروني');
  static String get phone => _t('Phone', 'الهاتف');
  static String get whatsapp => _t('WhatsApp', 'واتساب');
  static String get credit => _t(
    'Developed by ${DeveloperInfo.nameEn} · ${DeveloperInfo.phone}',
    'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.phone}',
  );

  /// Display-only formatting of an amount in piasters as EGP.
  static String price(int piasters) {
    final pounds = piasters / 100;
    final text = pounds == pounds.roundToDouble()
        ? pounds.toStringAsFixed(0)
        : pounds.toStringAsFixed(2);
    return _t('EGP $text', '$text ج.م');
  }

  static String priceFrom(int piasters) =>
      _t('From ${price(piasters)}', 'يبدأ من ${price(piasters)}');
}
