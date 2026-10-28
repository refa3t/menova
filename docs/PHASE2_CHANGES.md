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
| — | — | — | — | لا تغييرات بعد | — | — |
