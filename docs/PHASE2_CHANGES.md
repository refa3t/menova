# تصنيف تغييرات المرحلة 2 وسجلها (P2-01)

> الهدف: إثبات أن الكريب يُضاف بتعريف وبيانات وقدرات جديدة فقط. كل تغيير في المرحلة 2 يُصنَّف هنا **قبل** دمجه، ويُسجَّل في السجل أسفل الملف مع الـ diff وسببه.
> المرجع: `CLAUDE.md` قسم 7 (المرحلة 2) وARC-01..09.

## 1. الفئات والوحدات

### مقبول (يمر دون مراجعة)

| النوع | الوحدات / المواضع |
| --- | --- |
| بيانات وأصول | `definitions/crepe.json`، `tools/seed/crepe_*.json`، `assets_src/crepe/**`، وثائق Firestore للكريب (seed) |
| تعريف كاتيجوري جديد | ملف تعريف جديد يمر بـ `validateDefinition` دون تعديل المُتحقِّق |
| نمط توزيع جديد | صنف جديد يطبّق `PlacementStrategy` في `packages/product_builder/lib/src/placement*.dart` + سطر تسجيل في `placementStrategies` |
| خطوة أنيميشن جديدة | ملف جديد في `packages/animation/lib/src/steps/` يطبّق `AnimStep` + سطر تسجيل في `animSteps` |
| ملف حركة دخول/خروج جديد | إضافة إلى `enterProfiles`/`exitProfiles` في `product_builder/motion.dart` |
| حقل اختياري جديد | حقل اختياري في نموذج، قيمته الافتراضية تُبقي سلوك البيتزا كما هو حرفياً (يثبته انحدار البيتزا) |
| أدوات | سكربتات `tools/` لتجهيز أصول الكريب (مثل `process_*.py`) |

### يستدعي مراجعة (يُسجَّل، يُراجَع أثره على البيتزا، ويُقرّ قبل الدمج)

| النوع | الوحدات |
| --- | --- |
| تعديل نموذج مشترك | `packages/core/lib/src/contracts/*` (Selection، OrderItem، Order، PriceBreakdown، RenderSnapshot، StepSequence)، `packages/core/lib/src/models/*` (CategoryDefinition، OptionGroup، Product، Ingredient، Asset) |
| تعديل حالة البناء | `packages/product_builder/lib/src/builder_state.dart`، `builder_canvas.dart` |
| نوع اختيار جديد | أي شكل اختيار غير (حجم، مجموعة خيارات، كمية مكوّن، ملاحظة) |
| تعديل منطق التسعير | `packages/pricing/**`، `test_vectors/pricing.json` |
| تعديل عام في السلة أو الطلب | `apps/storefront/lib/features/cart/**`، `features/checkout/**`، `features/order/**`، `firestore.rules` |
| تعديل عام في لوحة الاستقبال | `apps/reception/**` |
| تعديل عام في شاشة البناء (المنسِّق) | `apps/storefront/lib/features/builder/**` |
| تعديل المُتحقِّق أو المحمّل | `packages/category_definitions/**` |

**الحكم:** التعديل **المعمَّم** (يخدم أي كاتيجوري، بلا ذكر للكريب) مقبول بعد المراجعة. شرطه: كل اختبارات البيتزا تنجح كما هي (انحدار P2-10).

### فشل معماري (توقف وراجع المعمارية)

- إعادة كتابة السلة أو الطلب أو التسعير **خصيصاً للكريب**.
- أي `if`/`switch` على اسم كاتيجوري أو منتج (`'crepe'`، `'pizza'`...) في المحركات أو التطبيقات.
- نسخ شاشة Builder أو أي شاشة لكاتيجوري بعينها.

## 2. حراس آليون (CI)

| الحارس | يمنع |
| --- | --- |
| `tools/test/engine_boundaries_test.dart` | استيراد محرك لمحرك آخر، وFlutter داخل `pricing` (ARC-03، ARC-04) |
| `tools/test/category_neutral_test.dart` | أي نص حرفي بمعرّف كاتيجوري أو منتج في كود المكتبات (ARC-01) |
| `validateDefinition` + `apps/storefront/test/definitions` | تعريف يشير لأصل أو خطوة أو استراتيجية غير مسجلة (fail-closed) |
| كل اختبارات البيتزا الحالية | أي تغيير مشترك يكسر البيتزا (انحدار) |

## 3. طريقة التسجيل

لكل تغيير خارج فئة «مقبول»: سطر في السجل أدناه فيه رقم المهمة، الملفات، الفئة، السبب، ولماذا هو معمَّم، ونتيجة انحدار البيتزا، ورابط الـ commit. يُراجع بـ `git diff <commit>^ <commit> -- <files>`.

## 4. السجل

| # | المهمة | الملفات | الفئة | السبب ولماذا هو معمَّم | انحدار البيتزا | commit |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | P2-02/03 | `tools/bin/seed.dart` | مقبول (أدوات) | المكوّن المعرَّف في ملف كاتيجوري تعيد استخدامه كاتيجوري أخرى بالمعرّف، و`allowedCategoryIds` لكل أصل تُحسب من كل التعريفات بدل كاتيجوري التشغيل. معمَّم: لا يذكر الكريب | seed البيتزا 112 وثيقة كما هي | `d5f0786` |
| 2 | P2-03 | `apps/storefront/test/definitions/definitions_test.dart` (كان `pizza_definition_test`) | مقبول (اختبار) | يتحقق من **كل** ملف في `definitions/` بأصول ومكونات كل الكاتيجوري | ناجح | `d5f0786` |
| 3 | P2-03 | `apps/storefront/lib/core/strings/app_strings.dart` (`searchHint`)، `features/menu/presentation/category_screen.dart` (أيقونة المجموعة) | يستدعي مراجعة (نص/واجهة عامة) | نص البحث كان «ابحث عن البيتزا» وأيقونة المجموعات بيتزا؛ صارا عامين («ابحث في المنيو»، أيقونة منيو). لا منطق جديد | 60 اختبار متجر ناجحة | `d5f0786` |
| 4 | P2-04 | `packages/product_builder/lib/src/placement.dart` (`BandPlacement`، `DrizzlePlacement`، `strategiesByIngredient`) | مقبول (نمط توزيع جديد + تسجيل) | الشريط للحشو والخطوط للصوصات، عبر نقطة التوسع نفسها | 26 اختبار توزيع ناجحة، والبيتزا على `rings` كما هي | (commit P2-04) |
| 5 | P2-04 | `packages/core/lib/src/models/category_definition.dart` (`PlacementSpec.byIngredient`) | مقبول (حقل اختياري) | استراتيجية لكل مكوّن داخل الكاتيجوري؛ فارغ افتراضياً فلا يتغير شيء في البيتزا | core 12 ناجحة | (commit P2-04) |
| 6 | P2-04 | `packages/category_definitions/lib/src/validator.dart` + اختباره | يستدعي مراجعة (المُتحقِّق) | يرفض `byIngredient` لمكوّن غير مسموح أو استراتيجية غير مسجلة (fail-closed). معمَّم | 8 ناجحة؛ واختبار «الرفض» صار يقبل أكثر من تعريف | (commit P2-04) |
| 7 | P2-04 | `packages/product_builder/lib/src/builder_canvas.dart` (`strategyByIngredient`)، `builder_screen.dart`، `product_preview.dart` | يستدعي مراجعة (البناء والمنسِّق) | اللوحة تأخذ استراتيجية المكوّن إن وُجدت وإلا العامة. معمَّم، بلا ذكر للكريب | متجر 63 ناجحة، والبيتزا كما هي على الموقع | (commit P2-04) |

## 5. تقرير P2-03 («بلا كود مكرر»)

أُضيف الكريب بـ: تعريف `definitions/crepe.json`، وبيانات `tools/seed/crepe_*.json`، وأصول مرسومة بالكود، وكلها مولّدة من `tools/build_crepe_catalog.py` و`tools/process_crepe_assets.py`.

| يعمل دون أي تعديل في المحركات أو السلة أو الطلب | التحقق |
| --- | --- |
| يظهر في الرئيسية (شريط) وفي صفحة قسمه بمجموعتيه (حادق، حلو) والبحث | يدوي على الموقع المنشور |
| يفتح الـ Builder بمكوناته الافتراضية، بلا محدد حجم (حجم واحد) | `crepe_test` + يدوي |
| الإضافة والحذف وحد `maxQty` والسعر | `crepe_test` |
| المكوّن المشترك بسعره وصورته من مصدر واحد (فراخ 35ج في البيتزا والكريب) | `crepe_test` + seed |
| السلة | يدوي (كريب فواكه 110ج في السلة) |
| الطلب ولوحة الاستقبال | مسار عام بلا ذكر للكاتيجوري، ولوحة الاستقبال أعيد بناؤها بالتعريفين لتتحقق من أسعار الكريب |

ما لم يكن بيانات فقط: البنود 1 إلى 3 أعلاه، ولا شيء منها خاص بالكريب. **لا فشل معماري.**

