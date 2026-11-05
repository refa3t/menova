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
    AdminArea.drafts => 'المسودات والنشر',
    AdminArea.assets => 'الصور',
    AdminArea.categories => 'الأقسام: الظهور والترتيب',
    AdminArea.offers => 'العروض والكوبونات',
    AdminArea.catalogCheck => 'فحص المنيو',
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

  // Ingredients (P3-03).
  static const ingredients = 'المكونات';
  static const editIngredient = 'تعديل المكوّن';
  static const extraPrice = 'سعر الإضافة (ج.م)';
  static const extraPriceHint = 'نفس السعر في كل الأقسام التي تستخدمه';
  static const image = 'الصورة';
  static const usedIn = 'يُستخدم في';
  static const ingredientsNote =
      'إضافة مكوّن جديد لقسم تتم مع تعريف القسم (من المطور).';

  // Images (P3-04).
  static const images = 'الصور';
  static const productPhotos = 'صور المنتجات';
  static const ingredientImages = 'صور المكونات';
  static const noPhoto = 'بلا صورة: يظهر رسم المكونات في المنيو';
  static const uploadPhoto = 'رفع صورة';
  static const replace = 'استبدال';
  static const replaceTitle = 'معاينة قبل الاعتماد';
  static const confirmReplace = 'اعتمد الصورة';
  static const cancel = 'إلغاء';
  static const uploading = 'جارٍ الرفع...';
  static const replaced = 'تم تحديث الصورة';
  static const uploadFailed = 'تعذّر الرفع. لم يتغير شيء';
  static const imagesNote =
      'PNG أو WebP بخلفية شفافة. الصورة القديمة تبقى محفوظة للرجوع. صور القواعد والحركة من المطور.';
  static const variantsNote =
      'يمكن اختيار حتى 5 صور: الأولى أساسية والباقي تنويعات للقطع.';
  static String fileIssue(String path, AssetSpec spec) => switch (path) {
    'format' => 'الصيغة يجب أن تكون PNG أو WebP',
    'bytes' => 'الحجم أكبر من ${spec.maxBytes ~/ 1024} كيلوبايت',
    'transparent' => 'الخلفية يجب أن تكون شفافة',
    _ => path,
  };

  // Categories and store settings (P3-05).
  static const categories = 'الأقسام';
  static const visibleOnSite = 'ظاهر في الموقع';
  static const hiddenOnSite = 'مخفي';
  static const moveUp = 'لأعلى';
  static const moveDown = 'لأسفل';
  static const categoriesNote =
      'إظهار القسم وترتيبه في الصفحة الرئيسية. إضافة قسم جديد تتم مع تعريفه (من المطور).';
  static const settings = 'إعدادات المطعم والتوصيل';
  static const storeLocation = 'موقع المطعم';
  static const lat = 'خط العرض (lat)';
  static const lng = 'خط الطول (lng)';
  static const openMap = 'افتح الموقع على الخريطة';
  static const perKm = 'سعر الكيلو (ج.م)';
  static const minFee = 'أقل رسوم توصيل (ج.م)';
  static const maxKm = 'أقصى مسافة توصيل (كم)';
  static const deliveryNote =
      'الرسوم = كل كيلو بدأ × سعر الكيلو، ولا تقل عن الحد الأدنى. تُطبَّق على الطلبات الجديدة فوراً.';
  static const invalidNumber = 'رقم غير صحيح';

  // Catalog check (P3-06).
  static const catalogCheck = 'فحص المنيو';
  static const catalogOk =
      'المنيو سليم: كل المنتجات والمكونات مطابقة لتعريف أقسامها.';
  static const catalogNote =
      'يراجع كل منتج على تعريف قسمه، وكل مكوّن وصورته. المنتج المخالف لا يُضاف للسلة بشكل صحيح، فأوقفه حتى يُصلَّح.';
  static const runCheck = 'افحص الآن';
  static const disableBroken = 'أوقف المنتجات المخالفة';
  static String findings(int n) => 'وُجدت $n مشكلة';
  static const productLabel = 'منتج';
  static const ingredientLabel = 'مكوّن';
  static const disabledDone = 'تم إيقاف المنتجات المخالفة';

  // Audit log (P3-07).
  static const auditLog = 'سجل التعديلات';
  static const auditEmpty = 'لا توجد تعديلات بعد';
  static String action(String a) => switch (a) {
    'saveProduct' => 'تعديل منتج',
    'saveIngredient' => 'تعديل مكوّن',
    'replaceAsset' => 'تغيير صورة',
    'setCategoryVisibility' => 'ظهور/ترتيب قسم',
    'saveStoreSettings' => 'إعدادات المطعم',
    'validateCatalog' => 'إيقاف بعد فحص المنيو',
    'saveOffer' => 'تعديل عرض',
    'saveCoupon' => 'تعديل كوبون',
    _ => a,
  };
  // Drafts and publishing (P3-09).
  static const drafts = 'المسودات والنشر';
  static const saveDraft = 'حفظ كمسودة';
  static const draftSaved = 'تم حفظ المسودة. انشرها من «المسودات والنشر»';
  static const pendingDraft = 'مسودة غير منشورة: العملاء يرون النسخة الحالية';
  static const discardDraft = 'تجاهل المسودة';
  static const draftsNote =
      'التعديلات المحفوظة كمسودة لا تظهر للعملاء حتى تُنشر. التوفر السريع من القوائم والصور يتغيران فوراً.';
  static const noDrafts = 'لا توجد مسودات بانتظار النشر';
  static String publishAll(int n) => 'نشر الكل ($n)';
  static const publish = 'نشر';
  static const publishing = 'جارٍ النشر...';
  static String published(int n) => 'تم نشر $n';
  static String notPublished(String names) => 'لم يُنشر (راجع التعديل): $names';
  static const newRecord = 'جديد';
  static String changedSince(String fields) =>
      'تغيّر منذ حفظ المسودة: $fields. النشر يستبدله.';
  static String draftKind(String kind) => kind == 'product' ? 'منتج' : 'مكوّن';

  /// Arabic name of a product or ingredient field.
  static String field(String key) => switch (key) {
    'name' => 'الاسم',
    'names' => 'الأسماء',
    'description' => 'الوصف',
    'basePrice' => 'السعر الأساسي',
    'sizeDeltas' => 'فروق الأحجام',
    'optionDeltas' => 'أسعار الخيارات',
    'defaults' => 'المكونات الافتراضية',
    'isAvailable' => 'التوفر',
    'displayOrder' => 'ترتيب العرض',
    'groupId' => 'القسم الفرعي',
    'extraPrice' => 'سعر الإضافة',
    'assetId' || 'imageAssetId' => 'الصورة',
    _ => key,
  };

  /// A field's value as people read it (prices in pounds).
  static String fieldValue(String key, Object? v) => switch ((key, v)) {
    (_, null) => '—',
    ('basePrice' || 'extraPrice', final int p) => price(p),
    ('sizeDeltas' || 'optionDeltas', final Map m) => [
      for (final e in m.entries)
        '${e.key}: ${e.value is int ? price(e.value as int) : e.value}',
    ].join('، '),
    ('names', final Map m) => m.values.join(' / '),
    ('defaults', final List l) => '${l.length}',
    ('isAvailable', final bool b) => b ? available : unavailable,
    _ => '$v',
  };

  // Offers and coupons (P3-09).
  static const offers = 'العروض والكوبونات';
  static const autoOffers = 'العروض التلقائية';
  static const autoOffersNote =
      'تُطبَّق وحدها على كل طلب يستوفي شروطها في فترتها.';
  static const coupons = 'الكوبونات';
  static const couponsNote =
      'يكتب العميل الكود في صفحة الطلب. كل طلب يأخذ عرضاً واحداً: الأكبر خصماً.';
  static const newOffer = 'عرض جديد';
  static const newCoupon = 'كوبون جديد';
  static const editOffer = 'تعديل العرض';
  static const editCoupon = 'تعديل الكوبون';
  static const noOffers = 'لا توجد عروض بعد';
  static const noCoupons = 'لا توجد كوبونات بعد';
  static const offerKind = 'نوع الخصم';
  static String kind(OfferKind k) => switch (k) {
    OfferKind.percent => 'نسبة مئوية',
    OfferKind.amount => 'مبلغ ثابت',
    OfferKind.freeDelivery => 'توصيل مجاني',
  };
  static const percentValue = 'النسبة (%)';
  static const amountValue = 'المبلغ (ج.م)';
  static const appliesTo = 'يُطبَّق على';
  static const wholeOrder = 'كل الطلب';
  static const minOrder = 'حد أدنى للطلب (ج.م، اختياري)';
  static const maxDiscountField = 'حد أقصى للخصم (ج.م، اختياري)';
  static const startDate = 'يبدأ';
  static const endDate = 'آخر يوم';
  static const noDate = 'بدون';
  static const pick = 'اختر';
  static const clear = 'مسح';
  static const activeLabel = 'مفعّل';
  static const couponCodeLabel = 'الكود (حروف إنجليزية وأرقام)';
  static const maxUsesField = 'عدد مرات الاستخدام (اختياري)';
  static const codeTaken = 'هذا الكود مستخدم لكوبون آخر';
  static String usedTimes(int uses, int? max) =>
      max == null ? 'استُخدم $uses مرة' : 'استُخدم $uses من $max';

  /// Where an offer stands now.
  static String offerState(Offer o, DateTime now) {
    final ms = now.millisecondsSinceEpoch;
    if (!o.isActive) return 'متوقف';
    if (o.startsAtMs case final s? when ms < s) return 'لم يبدأ';
    if (o.endsAtMs case final e? when ms >= e) return 'انتهى';
    if (o.maxUses case final m? when o.uses >= m) return 'نفد';
    return 'يعمل الآن';
  }

  /// One line on what an offer gives and when ([category]: its name).
  static String offerSummary(Offer o, String? category) {
    final scope = category == null ? wholeOrder : 'قسم $category';
    final cap = o.maxDiscount == null
        ? ''
        : ' بحد أقصى ${price(o.maxDiscount!)}';
    final parts = [
      switch (o.kind) {
        OfferKind.percent => '${o.value}% على $scope$cap',
        OfferKind.amount => '${price(o.value)} خصم على $scope',
        OfferKind.freeDelivery =>
          category == null
              ? 'توصيل مجاني$cap'
              : 'توصيل مجاني لطلبات $category$cap',
      },
      if (o.minSubtotal > 0) 'لطلبات من ${price(o.minSubtotal)}',
      if (o.startsAtMs case final s?)
        'من ${date(DateTime.fromMillisecondsSinceEpoch(s))}',
      if (o.endsAtMs case final e?)
        'حتى ${date(DateTime.fromMillisecondsSinceEpoch(e - 1))}',
    ];
    return parts.join(' · ');
  }

  /// A whole number typed by the admin (Arabic or Latin digits); null if it
  /// is not one.
  static int? parseCount(String text) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    final latin = text.trim().split('').map((c) {
      final i = arabic.indexOf(c);
      return i >= 0 ? '$i' : c;
    }).join();
    return RegExp(r'^\d{1,6}$').hasMatch(latin) ? int.parse(latin) : null;
  }

  // Reports (P3-08).
  static const reports = 'التقارير والمبيعات';
  static String lastDaysLabel(int n) =>
      n <= 10 ? 'آخر $n أيام' : 'آخر $n يوماً';
  static const refresh = 'تحديث';
  static const reportsNote =
      'تُحسب كل الطلبات عدا الملغاة والمستردة، بأسعارها المجمّدة وقت الطلب.';
  static String period(DateTime from, DateTime last) =>
      'من ${day(from)} حتى ${day(last)}';
  static String excluded(int n) => 'مستبعد: $n (ملغى أو مسترد)';
  static String unreadable(int n) => 'تعذّرت قراءة $n طلب';
  static const ordersLabel = 'الطلبات';
  static const salesLabel = 'المبيعات';
  static const deliveryFees = 'منها رسوم التوصيل';
  static const discounts = 'خصومات العروض';
  static const averageOrder = 'متوسط الطلب';
  static const dailySales = 'المبيعات اليومية (ج.م)';
  static const weeklySales = 'المبيعات الأسبوعية';
  static const weekNote = 'الأسبوع من السبت إلى الجمعة';
  static const bestSellers = 'الأكثر مبيعاً';
  static const bestSellersNote = 'المنتجات بعدد القطع المباعة';
  static const topAddOns = 'الإضافات الأكثر طلباً';
  static const addOnsNote =
      'المكونات الإضافية فوق الافتراضي والخيارات المدفوعة مثل الحواف';
  static const noSales = 'لا توجد مبيعات في هذه الفترة';
  static const showTable = 'عرض كجدول';
  static const showChart = 'عرض كرسم';
  static const dayCol = 'اليوم';
  static const weekCol = 'الأسبوع';
  static const salesCol = 'المبيعات (ج.م)';
  static const averageCol = 'متوسط الطلب (ج.م)';
  static String dayTip(DateTime d, int orders, int piasters) =>
      '${day(d)}\n${amount(piasters)} · $ordersLabel: $orders';

  static const _weekdays = [
    'الاثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
    'السبت',
    'الأحد',
  ];
  static const _months = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];
  static String weekday(DateTime d) => _weekdays[d.weekday - 1];
  static String date(DateTime d) => '${d.day} ${_months[d.month - 1]}';
  static String day(DateTime d) => '${weekday(d)} ${date(d)}';
  static String week(DateTime start) =>
      '${date(start)} - ${date(DateTime(start.year, start.month, start.day + 6))}';

  /// A whole number with thousands separators (1,250).
  static String grouped(int n) => n.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );

  /// Piasters as pounds with thousands separators (1,250 or 117.69).
  static String pounds(int piasters) {
    final rest = piasters.abs() % 100;
    final whole = '${piasters < 0 ? '-' : ''}${grouped(piasters.abs() ~/ 100)}';
    return rest == 0 ? whole : '$whole.${rest.toString().padLeft(2, '0')}';
  }

  /// [pounds] with the currency, for reports.
  static String amount(int piasters) => '${pounds(piasters)} ج.م';

  static String when(DateTime? at) {
    if (at == null) return '';
    final l = at.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

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
      'extraPrice' => 'سعر الإضافة لا يكون سالباً',
      'assetId' => 'اختر صورة من صور المكونات',
      'sizeMultipliers' => 'معامل الحجم غير صحيح',
      'value' => 'القيمة: النسبة من 1 إلى 100، والمبلغ 1 ج.م على الأقل',
      'endsAtMs' => 'آخر يوم قبل يوم البداية',
      'maxDiscount' => 'الحد الأقصى للخصم 1 ج.م على الأقل',
      'maxUses' => 'عدد مرات الاستخدام 1 على الأقل',
      'code' => 'الكود من 3 إلى 20 حرفاً إنجليزياً أو رقماً أو شرطة',
      'minSubtotal' => 'الحد الأدنى للطلب لا يكون سالباً',
      _ => path,
    };
  }

  static const credit =
      'تطوير ${DeveloperInfo.nameAr} · ${DeveloperInfo.email} · ${DeveloperInfo.phone}';
}
