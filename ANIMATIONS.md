# ANIMATIONS.md — مواصفات الحركة (menova)

> يحدد حركة كل مكوّن عند الإضافة والحذف، وحركات الواجهة الصغيرة، وتسلسل «أضف للسلة» للبيتزا (الفرن ثم التبديل ثم الطيران للسلة).
> **كل الأرقام (ميلي ثانية، نسب، منحنيات) مقترحة** وتُعاير على المرجع البصري المعتمد (AC-11 وAC-12) وعلى جهاز متوسط فعلي (AC-14). لا تُنفَّذ كحقائق نهائية.
> يُقرأ مع `CLAUDE.md` (قسم 5.5) و`PIZZA_CATALOG.md` (المفاتيح) و`ASSETS.md`.

---

## 0) ثلاث طبقات حركة، ولكل طبقة مالكها

| الطبقة | ماذا تشمل | من يملكها (ARC) | المهام |
| --- | --- | --- | --- |
| **أ) حركة المكونات** (Enter/Exit) | دخول وخروج قطع كل مكوّن على المنتج | محرك بناء المنتج (يرسم الطبقات) | P1-B03 وP1-B04 |
| **ب) حركات الواجهة الصغيرة** | تغيير الحجم، العجينة، عدّاد السعر، شبكة المكونات، الأزرار، إعادة الضبط | المنسِّق (شاشة Builder) والواجهة | P1-C* وP1-D03 وP1-G05 |
| **ج) تسلسل «أضف للسلة»** | فرن ← تبديل ← طيران للسلة | **محرك الأنيميشن** (Step Runner) | P1-G01 إلى P1-G06 |

**قاعدة الفصل:** محرك الأنيميشن (ج) لا يعرف شيئاً عن حركة المكونات (أ) ولا عن السعر. وحركة المكونات تتبع «ملف حركة» (Profile) يُربط بكل مكوّن في تعريف الكاتيجوري (حقل بنيوي يملكه المطور)، وإضافة ملف حركة جديد قدرة جديدة تُطوَّر مرة واحدة (ARC-08).

---

## 1) قواعد عامة لكل الحركات

- **الافتراضي بلا حركة:** مكونات المنتج الجاهز تظهر من أول فريم ثابتة. الحركة فقط لما يفعله العميل.
- **إضافة = مجموعة جديدة:** كل ضغطة (+1) تضيف مجموعة قطع جديدة بـ seed مختلف (`id + "extra"`)، ولا تُعاد حركة القطع الموجودة ولا يُعاد توزيعها.
- **التوزيع قبل الحركة:** أماكن القطع النهائية تُحسب أولاً (ثابتة، بلا تداخل مفرط)، ثم تتحرك كل قطعة من نقطة بدايتها إلى مكانها.
- **سقف القطع المتحركة معاً:** 60 قطعة. إن زادت تُقسَّم على دفعات أو تُحذف حركة القطع الأصغر (تظهر بـ fade).
- **سقف زمن الحركة الكلي للمكوّن:** `cap` في جدول القسم 2 مهما كثر عدد القطع، فيُضغط الـ stagger تلقائياً.
- **تقليل الحركة (Reduce Motion):** كل الدخول يصبح fade-in 120ms بلا stagger ولا إزاحة، والخروج fade-out 100ms.
- **الأداء:** الـ Canvas داخل `RepaintBoundary`. الحركة بـ `Transform` و`Opacity` فقط، بلا تغيير تخطيط ولا `saveLayer` داخل الحلقة. (راجع `CLAUDE.md` P1-B06.)
- **أثناء حركة الدخول** يبقى زر المكوّن في الشبكة قابلاً للضغط، ويُلغى ما لم يبدأ من الضغطات ولا يُحجب الباقي (الضغط المتكرر السريع يضيف مجموعات متتالية).

---

## 2) ملفات حركة الدخول (Enter Profiles)

قيم الإزاحة نسبة من قطر المنتج (القاعدة = 100%). الدوران بالدرجات حول الاتجاه النهائي. المدة لكل قطعة.

| الملف | الوصف | بداية السقوط (Y) | مقياس البداية | دوران | Fade | المنحنى | المدة/قطعة | Stagger (+عشوائي) | سقف الكلي | عند الهبوط |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `drop` | سقوط (شرائح صلبة) | -18% | 1.25 ← 1 | ±20° | 0 إلى 1 في أول 35% | easeOutBack (overshoot ≈ 8%) | 380ms | 35ms (+0 إلى 60ms) | 900ms | ضغط عند الهبوط: scale 1 ← 0.94 ← 1 خلال 120ms + ظل خفيف يظهر |
| `shower` | رشّة (خصلات وفتات) | -22% | 0.6 ← 1 | ±10° | 0 إلى 1 في أول 40% | easeOut | 520ms | 18ms (+0 إلى 30ms) | 800ms | استقرار scale 1.04 ← 1 خلال 100ms |
| `sprinkle` | نثر (قطع صغيرة جداً) | -28% | 0.8 ← 1 | ±90° | 0 إلى 1 في أول 25% | easeOutQuad | 650ms | 12ms (+0 إلى 20ms) | 800ms | بدون ارتداد |
| `float` | طفو (أوراق) | -20% | 0.8 ← 1 | ±30° | 0 إلى 1 في أول 30% | easeInOutCubic | 700ms | 70ms (+0 إلى 40ms) | 1000ms | استقرار scale 1.03 ← 1 خلال 120ms، مع تمايل أفقي ±3% أثناء الهبوط |
| `toss` | قذف (قطع لحم وبحر) | -15% | 1.1 ← 1 | ±45° | 0 إلى 1 في أول 30% | easeOutCubic (مسار قوس، ذروة 8%) | 480ms | 45ms (+0 إلى 40ms) | 900ms | ضغط scale 1 ← 0.95 ← 1 خلال 100ms |

- **نقطة البداية الأفقية:** `drop` و`toss` و`float` من فوق موضع القطعة بإزاحة أفقية عشوائية ±8%. `shower` و`sprinkle` من منطقة أعلى المنتج (±12% و±6% حول موضع القطعة).
- **`toss`:** مسار قوس (Bezier تربيعي) من أقرب جانب علوي، بذروة 8% فوق الموضع.
- **`float`:** مسار S خفيف (تمايل جيبي ±3% أفقياً أثناء الهبوط).

---

## 3) ملفات حركة الخروج (Exit Profiles)

تُطبَّق على قطع المكوّن المحذوف فقط، بترتيب عكسي (آخر قطعة دخلت أول من يخرج).

| الملف | الوصف | المدة/قطعة | Stagger | سقف الكلي |
| --- | --- | --- | --- | --- |
| `liftFade` | رفع وتلاشي: scale 1 ← 0.7، إزاحة لأعلى −6%، opacity 1 ← 0، دوران +10°، منحنى easeIn | 220ms | 12ms | 400ms |
| `dissolve` | ذوبان: opacity 1 ← 0 مع scale 1 ← 0.85، منحنى easeOut | 180ms | 8ms | 300ms |
| `retract` | انسحاب الصلصة: عكس مسار الرسم (trim من النهاية للبداية)، منحنى easeInOut | 300ms | 0ms | 300ms |

ربط الخروج بملف الدخول: `drop` ← `liftFade`، `toss` ← `liftFade`، `float` ← `liftFade`، `shower` ← `dissolve`، `sprinkle` ← `dissolve`، `drizzle` ← `retract`.

---

## 4) حركة كل مكوّن (الربط والكثافة)

38 مكوّناً. «الكثافة» = عدد القطع لكل **وحدة كمية** (+1). **قيم أولية للمعايرة** على شكل البيتزا في Prototype الرسم (P1-B00).

| key | المكوّن | ملف الدخول | ملف الخروج | الكثافة (قطعة/وحدة) | ملاحظة |
| --- | --- | --- | --- | --- | --- |
| `mozzarella` | موزاريلا | `shower` | `dissolve` | 14 | تتمدد قليلاً عند الهبوط (scaleX 1.06 ثم 1) |
| `cheddar` | شيدر | `shower` | `dissolve` | 14 | تتمدد قليلاً عند الهبوط (scaleX 1.06 ثم 1) |
| `roumi` | رومي | `shower` | `dissolve` | 14 |  |
| `feta` | فيتا | `shower` | `dissolve` | 12 |  |
| `blue_cheese` | جبنة زرقاء | `shower` | `dissolve` | 10 |  |
| `parmesan` | بارميزان | `sprinkle` | `dissolve` | 20 |  |
| `pepperoni` | بيبروني | `drop` | `liftFade` | 10 | ارتداد كامل + ضغط عند الهبوط |
| `salami_spicy` | سلامي حار | `drop` | `liftFade` | 10 |  |
| `ham` | هام | `drop` | `liftFade` | 9 | يهبط مع انحناء بسيط (scaleY 0.9 ثم 1) |
| `sausage` | سوسيس | `drop` | `liftFade` | 9 |  |
| `bacon` | بيكون | `drop` | `liftFade` | 10 | دوران أقل (±10°) لأنه شريط |
| `ground_beef` | لحمة مفرومة | `shower` | `dissolve` | 24 | قطع صغيرة كثيفة، سقف الحركة 700ms |
| `chicken` | فراخ | `toss` | `liftFade` | 12 | قفزة صغيرة عند الهبوط |
| `basterma` | بسطرمة | `drop` | `liftFade` | 9 |  |
| `mortadella` | مرتديلا | `drop` | `liftFade` | 9 |  |
| `tuna` | تونة | `shower` | `dissolve` | 14 |  |
| `shrimp` | جمبري | `toss` | `liftFade` | 6 |  |
| `calamari` | حلقات حبار | `toss` | `liftFade` | 10 |  |
| `anchovy` | أنشوجة | `toss` | `liftFade` | 8 |  |
| `bell_pepper_green` | فلفل أخضر | `drop` | `liftFade` | 10 | دوران أقل (±10°) لأنه شريط |
| `bell_pepper_red` | فلفل أحمر | `drop` | `liftFade` | 10 | دوران أقل (±10°) لأنه شريط |
| `mushroom` | مشروم | `drop` | `liftFade` | 12 | دوران أقل (±12°) |
| `onion` | بصل | `drop` | `liftFade` | 14 | سقوط أخف (−40ms) |
| `red_onion` | بصل أحمر | `drop` | `liftFade` | 14 | سقوط أخف (−40ms) |
| `tomato` | طماطم | `drop` | `liftFade` | 8 | سقوط أبطأ قليلاً (+60ms) لأن الشريحة أكبر |
| `cherry_tomato` | طماطم كرزية | `drop` | `liftFade` | 10 |  |
| `olive_black` | زيتون أسود | `drop` | `liftFade` | 14 | ارتداد أخف (overshoot 4%) |
| `olive_green` | زيتون أخضر | `drop` | `liftFade` | 14 | ارتداد أخف (overshoot 4%) |
| `corn` | ذرة | `sprinkle` | `dissolve` | 30 | عناقيد صغيرة تتناثر فرادى |
| `pineapple` | أناناس | `drop` | `liftFade` | 10 |  |
| `jalapeno` | هالبينو | `drop` | `liftFade` | 14 |  |
| `chili_red` | فلفل حار أحمر | `drop` | `liftFade` | 12 |  |
| `artichoke` | خرشوف | `toss` | `liftFade` | 8 |  |
| `capers` | كبر | `sprinkle` | `dissolve` | 14 |  |
| `garlic` | ثوم | `drop` | `liftFade` | 14 |  |
| `basil` | ريحان | `float` | `liftFade` | 8 | يتمايل أفقياً ±3% أثناء الهبوط |
| `oregano` | أوريجانو | `sprinkle` | `dissolve` | 18 | ينثر من منتصف الأعلى |
| `parsley` | بقدونس | `sprinkle` | `dissolve` | 18 | ينثر من منتصف الأعلى |

**الصلصات** (تُرسم بالكود، بلا صور، ملف دخول `drizzle`):

| key | الصلصة | اللون | الحركة |
| --- | --- | --- | --- |
| `bbq_sauce` | صلصة باربكيو | `#5a2a14` | مسار متعرج (2 إلى 3 تمريرات) يُكشف تدريجياً خلال 700ms، سُمك 6 إلى 9 وحدات، `easeInOut`، سقف 900ms. الخروج `retract` |
| `ranch_sauce` | صلصة رانش | `#f3ead7` | مسار متعرج (2 إلى 3 تمريرات) يُكشف تدريجياً خلال 700ms، سُمك 6 إلى 9 وحدات، `easeInOut`، سقف 900ms. الخروج `retract` |
| `garlic_sauce` | صلصة ثوم | `#fbf6ea` | مسار متعرج (2 إلى 3 تمريرات) يُكشف تدريجياً خلال 700ms، سُمك 6 إلى 9 وحدات، `easeInOut`، سقف 900ms. الخروج `retract` |
| `hot_sauce` | صلصة حارة | `#d6401d` | مسار متعرج (2 إلى 3 تمريرات) يُكشف تدريجياً خلال 700ms، سُمك 6 إلى 9 وحدات، `easeInOut`، سقف 900ms. الخروج `retract` |
| `pesto` | بيستو | `#5f8f3a` | بقع خضراء: 6 بقع، تكبر من 0 إلى 1 بـ `easeOutBack` بفاصل 80ms. الخروج `dissolve` |

> صلصة الطماطم جزء من صورة القاعدة، فلا حركة لها.

---

## 5) حالات الكمية والحذف وإعادة الضبط

| الفعل | الحركة |
| --- | --- |
| إضافة مكوّن (+1) | حركة دخول بملفه، مجموعة جديدة بـ seed جديد |
| تكرار الإضافة (+2، +3...) | مجموعة جديدة لكل ضغطة، بنفس الملف، وتُحجب عند `maxQty` برجّة (shake) خفيفة للزر 200ms ورسالة |
| تقليل الكمية (−1) | تخرج **آخر مجموعة** أُضيفت فقط (خروج) |
| حذف مكوّن افتراضي (−) | خروج كل قطع المكوّن، وتظهر شارة «بدون X» بـ `easeOutBack` 200ms |
| إعادة المكوّن الافتراضي المحذوف | دخول بملفه، وتختفي شارة «بدون X» |
| إعادة الضبط (Reset) | المضاف يخرج بترتيب عكسي (سقف 500ms)، والمحذوف الافتراضي يعود بـ fade-in 200ms |
| فتح المنتج | الـ Canvas يظهر بـ fade + scale 0.96 ← 1 خلال 250ms. المكونات الافتراضية ثابتة |

---

## 6) حركات الواجهة الصغيرة

| العنصر | الحركة | المدة | المنحنى |
| --- | --- | --- | --- |
| تغيير الحجم | تكبير/تصغير الـ Canvas كله: S=0.82، M=0.91، L=1.0 | 280ms | `easeOutBack` |
| تغيير العجينة | crossfade بين صورتي القاعدة + نبضة scale 1.02 ← 1 | 250ms | `easeInOut` |
| عدّاد السعر | عدّ متحرك للرقم (Tween). وعند الزيادة وميض لون التمييز على الرقم 200ms | 300ms | `easeOutCubic` |
| ضغط مكوّن في الشبكة | حلقة تنبض (scale 1 ← 1.08 ← 1) + شارة ✓ أو عدّاد تظهر بـ pop | 180ms + 220ms | `easeOut` ثم `easeOutBack` |
| زر − (حذف) | يظهر بـ pop عند الضغط على مكوّن افتراضي | 160ms | `easeOutBack` |
| زر «أضف» (الحالات) | عادي ← مشغول (يتقلص قليلاً مع مؤشر) ← نجاح (أخضر ✓) ← يعود | 150ms لكل انتقال | `easeInOut` |
| رسالة تجاوز الحد | رجّة أفقية للزر ±6px مرتين | 200ms | `easeInOut` |

---

## 7) تسلسل «أضف للسلة» للبيتزا: فرن ← تبديل ← طيران

التسلسل (StepSequence) يُعرَّف في تعريف كاتيجوري البيتزا ويُشغَّله محرك الأنيميشن. المجموع **2.0 ثانية** (هدف ≤ 2.5 ثانية يُقاس ولا يُفترض).

| الخطوة | الوزن | من ← إلى | ماذا يحدث |
| --- | --- | --- | --- |
| 0) لحظة الضغط | — | 0ms | **تُضاف البنود للسلة ذرّياً فوراً** (ARC-07)، يُلتقط `RenderSnapshot` من الـ Canvas بكل المكونات، ويُقفل الزر (حالة مشغول) |
| 1) `Oven` | 50% | 0 ← 1000ms | انظر التفصيل أدناه |
| 2) `Swap` | 12% | 1000 ← 1250ms | انظر التفصيل أدناه |
| 3) `FlyToCart` | 38% | 1250 ← 2000ms | انظر التفصيل أدناه |

### الخطوة 1: `Oven` (0 إلى 1000ms)

| الزمن | الحدث |
| --- | --- |
| 0 إلى 250ms | طبقة تعتيم (Scrim) تظهر 0 ← 35% خلف المنتج. نار الفرن (Lottie `anim_oven_fire`) تظهر خلف البيتزا وحولها بـ fade-in. القطع «تستقر»: scale 1 ← 0.98 |
| 150 إلى 850ms | البيتزا (اللقطة) تتقلص 1 ← 0.9 كأنها تدخل عمق الفرن، وتتحرك للأسفل 2%. توهج برتقالي حول الحافة (ظل BoxShadow بنصف قطر 0 ← 40 ثم يثبت) |
| 300 إلى 800ms | **تسوية:** crossfade من صورة القاعدة النيئة إلى المسوّية. تدرّج لوني دافئ فوق المكونات (مضاعفة `#FFB066` بشدة 0 ← 18%) |
| 400 إلى 800ms | اهتزاز طفيف (Sizzle) للقطع ±0.6px بتردد ~24Hz، وبخار خفيف يصعد (جسيمات أو Lottie) |
| 850 إلى 1000ms | ذروة التوهج ثم يهدأ، والنار تبدأ بالتلاشي |

### الخطوة 2: `Swap` (1000 إلى 1250ms)

- النار والتعتيم يختفيان (fade-out 200ms).
- **دائماً لقطة بيتزا العميل المسوّاة** (بحجمها وعجينتها ومكوناتها المضافة والمحذوفة كما اختارها)، دون استبدالها بصورة ثابتة. الصورة النهائية الثابتة للمنتج (`finalImage`) تُستخدم في المنيو فقط.
- هذا قرار المطور: البيتزا التي رآها العميل وبناها هي نفسها التي تدخل الفرن وتطير للسلة.
- نبضة «بوب»: scale 0.9 ← 1.04 ← 1.0 بـ `easeOutBack`.

### الخطوة 3: `FlyToCart` (1250 إلى 2000ms)

| الزمن | الحدث |
| --- | --- |
| 1250 إلى 1850ms | المنتج يتقلص إلى 18% من حجمه ويطير على قوس (Bezier تربيعي، نقطة التحكم فوق المسار بـ 20% من المسافة) من مركز الـ Canvas إلى أيقونة السلة، مع دوران −12° ← 0، بمنحنى `easeInOutCubic` |
| 1850ms (الوصول) | أيقونة السلة تنبض scale 1 ← 1.18 ← 1 خلال 220ms (`easeOutBack`)، والعدّاد يزيد +1 بـ pop، واهتزاز لمس خفيف على الموبايل |
| 1850 إلى 2000ms | الـ Canvas يعود لحالته الطبيعية (المنتج يُعاد للعرض بحالته الحالية) |
| بعد 2000ms | زر «أضف» يتحول لأخضر ✓ «تمت الإضافة» لمدة 1200ms ثم يعود للحالة العادية |

### الحالات الخاصة

| الحالة | السلوك |
| --- | --- |
| الضغط على الشاشة أثناء الحركة (تخطي) | يقفز التسلسل لآخر خطوة: `FlyToCart` مختصرة 300ms. البند أُضيف أصلاً |
| الضغط المتكرر على «أضف» | الزر مقفل أثناء الحركة، فبند واحد فقط (AC-16) |
| الرجوع أو الإغلاق أثناء الحركة | تُلغى الحركة بنظافة، وبند السلة يبقى مكتملاً دون تكرار (AC-17، AC-30) |
| فشل تحميل Lottie النار | يُتخطى `Oven` بصرياً: يُستبدل بـ crossfade للتسوية + توهج بالكود، ولا يتأثر البند |
| تقليل الحركة | تُحذف `Oven`. تبقى `Swap` (crossfade 150ms) ثم `FlyToCart` خطية 400ms بلا دوران ولا نبضة، والمجموع ≤ 600ms (AC-15) |
| الحجم (S/M/L) | الحركة نفسها على اللقطة بحجمها الحالي، فلا حركة مختلفة لكل حجم |

---

## 8) الصوت واللمس (اختياري)

| الحدث | صوت | لمس |
| --- | --- | --- |
| وصول المنتج للسلة | `sfx_add_to_cart.mp3` | خفيف (Light) |
| دخول الفرن | `sfx_oven.mp3` (حفيف النار) | — |
| تجاوز `maxQty` | — | تحذير خفيف |

المتصفح يمنع تشغيل الصوت قبل أي تفاعل من المستخدم، فيُفعَّل بعد أول ضغطة. الصوت واللمس يُطفآن في وضع تقليل الحركة.

---

## 9) الإعداد الآلي (للتنفيذ)

نسخة قابلة للقراءة آلياً من ما سبق. تُحمَّل كتعريف حركة المكونات وتسلسل الكاتيجوري (حقول يملكها المطور).

```json
{
  "enterProfiles": {
    "drop": {
      "fromYPct": -18,
      "fromScale": 1.25,
      "spinDeg": 20,
      "curve": "easeOutBack",
      "durMs": 380,
      "staggerMs": 35,
      "jitterMs": 60,
      "capMs": 900
    },
    "shower": {
      "fromYPct": -22,
      "fromScale": 0.6,
      "spinDeg": 10,
      "curve": "easeOut",
      "durMs": 520,
      "staggerMs": 18,
      "jitterMs": 30,
      "capMs": 800
    },
    "sprinkle": {
      "fromYPct": -28,
      "fromScale": 0.8,
      "spinDeg": 90,
      "curve": "easeOutQuad",
      "durMs": 650,
      "staggerMs": 12,
      "jitterMs": 20,
      "capMs": 800
    },
    "float": {
      "fromYPct": -20,
      "fromScale": 0.8,
      "spinDeg": 30,
      "curve": "easeInOutCubic",
      "durMs": 700,
      "staggerMs": 70,
      "jitterMs": 40,
      "capMs": 1000
    },
    "toss": {
      "fromYPct": -15,
      "fromScale": 1.1,
      "spinDeg": 45,
      "curve": "easeOutCubic",
      "durMs": 480,
      "staggerMs": 45,
      "jitterMs": 40,
      "capMs": 900
    }
  },
  "exitProfiles": {
    "liftFade": {
      "durMs": 220,
      "staggerMs": 12,
      "capMs": 400
    },
    "dissolve": {
      "durMs": 180,
      "staggerMs": 8,
      "capMs": 300
    },
    "retract": {
      "durMs": 300,
      "staggerMs": 0,
      "capMs": 300
    }
  },
  "ingredients": {
    "mozzarella": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 14
    },
    "cheddar": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 14
    },
    "roumi": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 14
    },
    "feta": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 12
    },
    "blue_cheese": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 10
    },
    "parmesan": {
      "enter": "sprinkle",
      "exit": "dissolve",
      "piecesPerUnit": 20
    },
    "pepperoni": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "salami_spicy": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "ham": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 9
    },
    "sausage": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 9
    },
    "bacon": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "ground_beef": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 24
    },
    "chicken": {
      "enter": "toss",
      "exit": "liftFade",
      "piecesPerUnit": 12
    },
    "basterma": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 9
    },
    "mortadella": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 9
    },
    "tuna": {
      "enter": "shower",
      "exit": "dissolve",
      "piecesPerUnit": 14
    },
    "shrimp": {
      "enter": "toss",
      "exit": "liftFade",
      "piecesPerUnit": 6
    },
    "calamari": {
      "enter": "toss",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "anchovy": {
      "enter": "toss",
      "exit": "liftFade",
      "piecesPerUnit": 8
    },
    "bell_pepper_green": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "bell_pepper_red": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "mushroom": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 12
    },
    "onion": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "red_onion": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "tomato": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 8
    },
    "cherry_tomato": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "olive_black": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "olive_green": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "corn": {
      "enter": "sprinkle",
      "exit": "dissolve",
      "piecesPerUnit": 30
    },
    "pineapple": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 10
    },
    "jalapeno": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "chili_red": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 12
    },
    "artichoke": {
      "enter": "toss",
      "exit": "liftFade",
      "piecesPerUnit": 8
    },
    "capers": {
      "enter": "sprinkle",
      "exit": "dissolve",
      "piecesPerUnit": 14
    },
    "garlic": {
      "enter": "drop",
      "exit": "liftFade",
      "piecesPerUnit": 14
    },
    "basil": {
      "enter": "float",
      "exit": "liftFade",
      "piecesPerUnit": 8
    },
    "oregano": {
      "enter": "sprinkle",
      "exit": "dissolve",
      "piecesPerUnit": 18
    },
    "parsley": {
      "enter": "sprinkle",
      "exit": "dissolve",
      "piecesPerUnit": 18
    }
  },
  "sauces": {
    "bbq_sauce": {
      "enter": "drizzle",
      "exit": "retract",
      "color": "#5a2a14"
    },
    "ranch_sauce": {
      "enter": "drizzle",
      "exit": "retract",
      "color": "#f3ead7"
    },
    "garlic_sauce": {
      "enter": "drizzle",
      "exit": "retract",
      "color": "#fbf6ea"
    },
    "hot_sauce": {
      "enter": "drizzle",
      "exit": "retract",
      "color": "#d6401d"
    }
  },
  "sizeScale": {
    "S": 0.82,
    "M": 0.91,
    "L": 1.0
  },
  "pizzaAddToCart": {
    "totalMs": 2000,
    "steps": [
      {
        "step": "Oven",
        "weight": 50,
        "fromMs": 0,
        "toMs": 1000,
        "params": {
          "fireLottie": "anim_oven_fire",
          "scrimMaxPct": 35,
          "shrinkTo": 0.9,
          "warmTint": "#FFB066",
          "warmTintMaxPct": 18,
          "rawToCookedMs": [
            300,
            800
          ],
          "sizzlePx": 0.6,
          "sizzleHz": 24
        }
      },
      {
        "step": "Swap",
        "weight": 12,
        "fromMs": 1000,
        "toMs": 1250,
        "params": {
          "source": "renderSnapshotCooked",
          "fallbackIfSnapshotFails": "finalImage",
          "popScale": [
            0.9,
            1.04,
            1.0
          ]
        }
      },
      {
        "step": "FlyToCart",
        "weight": 38,
        "fromMs": 1250,
        "toMs": 2000,
        "params": {
          "shrinkTo": 0.18,
          "arcControlPct": 20,
          "rotateDeg": -12,
          "curve": "easeInOutCubic",
          "cartPulse": [
            1,
            1.18,
            1
          ],
          "cartPulseMs": 220,
          "successHoldMs": 1200
        }
      }
    ],
    "commitToCartAt": "press",
    "reducedMotion": {
      "steps": [
        "Swap",
        "FlyToCart"
      ],
      "totalMaxMs": 600
    },
    "skipOnTap": {
      "flyMs": 300
    }
  }
}
```

---

## 10) الربط بالمهام ومعايير القبول

| المهمة | ما تنفذه من هذا الملف |
| --- | --- |
| P1-B03 | توزيع القطع النهائية قبل الحركة |
| P1-B04 | ملفات الدخول والخروج وكثافة المكونات (القسمان 2 إلى 5) |
| P1-B07 | سجل ملفات الحركة (Map بسيط) كنقطة توسع، بلا نظام Plugins |
| P1-C03 | حركات شبكة المكونات والشارات (قسم 6) |
| P1-D03 | عدّاد السعر المتحرك |
| P1-G01 إلى P1-G04 | تسلسل `Oven` ثم `Swap` ثم `FlyToCart` (قسم 7) |
| P1-G05 | حالات زر «أضف» وتقليل الحركة |
| P1-G06 | مطابقة المرجع وضبط التوقيتات |

**معايير قبول مرتبطة:** AC-11 (مرجع معتمد) · AC-12 (مطابقة اللقطات والمدة) · AC-14 (قياس على جهاز متوسط) · AC-15 (تقليل الحركة) · AC-16 (ضغط متكرر) · AC-17 (رجوع أثناء الحركة) · AC-30 (فشل الحركة لا يغيّر البند).

---

## 11) نقاط تُحسم بالمرجع البصري (P0-06)

- هل تدخل البيتزا الفرن بحركة **انزلاق** (تتحرك فعلاً لعمق الفرن) أم تبقى مكانها والنار تظهر حولها (كما في الفيديو الحالي)؟ المقترح هنا الثاني مع تقلص بسيط.
- مدة الفرن (1000ms) وشدة التوهج والتسوية.
- هل تبقى المكونات «نيئة» ويتولى لون دافئ إظهار الطهي، أم تلزم نسخ مسوّاة للأكثر ظهوراً؟
- (حُسم) البيتزا التي تدخل الفرن هي لقطة اختيار العميل دائماً.
- ترتيب تراكب الطبقات أثناء الهبوط (الجبن تحت أم فوق).

> كاتيجوري الكريب (جريل ← طي ← تبديل ← طيران) والتورتيلا والطاسة لها تسلسلاتها الخاصة وتُكتب في المرحلة 2 وما بعدها، وليست هنا.
