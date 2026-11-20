"""Generate the cheese pan definition, seed data and catalog document.

The cheese pan (طاسة الجبنة): a small cast-iron pan of cheese with
toppings, baked until it bubbles. Owner request: the full category now.
Prices are Egyptian-market estimates (Banha, 2026) set by the developer at
the owner's request, in line with the pizza and crepe prices. Two sizes:
single and sharing.

Usage (from repo root): python tools/build_cheese_pan_catalog.py
Outputs: definitions/cheese_pan.json, definitions/cheese_pan.temp.json,
         tools/seed/cheese_pan_ingredients.json,
         tools/seed/cheese_pan_products.json,
         CHEESE_PAN_CATALOG.md (readable: products, ingredients, extras,
         prices)

Most ingredients and every sauce reuse the pizza records (one record, one
price and one image per ingredient, tools/seed/pizza_ingredients.json);
only the new ones are defined here (images:
tools/process_cheese_pan_assets.py).
"""
import glob
import json
import os
import re
from pathlib import Path

from build_pizza_catalog import (DRAWN_CHEESES, SAUCE_ANGLES, SAUCE_POUR,
                                 SAUCES, sauce_params, sprite_fill)
from process_cheese_pan_assets import PAN_SURFACE

EGP = 100

# New ingredients introduced by the cheese pan: id, Arabic, English, extra
# EGP, pieces per unit, piece size, enter motion.
NEW_INGREDIENTS = [
    ('hot_dog', 'هوت دوج', 'Hot dog', 30, 12, 0.085, 'drop'),
    ('smoked_turkey', 'تركي مدخن', 'Smoked turkey', 35, 6, 0.15, 'drop'),
]

# Reused pizza ingredients the pan allows: cheeses, meats, seafood,
# vegetables and herbs.
SHARED = [
    'mozzarella', 'cheddar', 'roumi', 'feta', 'parmesan', 'blue_cheese',
    'sausage', 'basterma', 'ground_beef', 'chicken', 'pepperoni',
    'mortadella', 'tuna', 'shrimp',
    'mushroom', 'bell_pepper_green', 'bell_pepper_red', 'onion', 'tomato',
    'olive_black', 'corn', 'jalapeno',
    'oregano', 'parsley',
]
HERBS = ['oregano', 'parsley']
SAUCE_IDS = [k for k, *_ in SAUCES]

# Sizes: a pan for one and a larger one to share.
SIZES = [('single', 'فردي', 'Single', 0.84),
         ('sharing', 'مشاركة', 'Sharing', 1.0)]

GROUPS = [('cheese', 'جبن وخضار', 'Cheese & veggies'),
          ('meat', 'لحوم وفراخ', 'Meat & chicken'),
          ('sea', 'بحري', 'Seafood')]

# id, Arabic, English, group, single EGP, sharing EGP, default ingredients.
PRODUCTS = [
    ('mixed_cheese', 'طاسة مشكل جبن', 'Mixed cheese pan', 'cheese', 110, 185,
     ['mozzarella', 'cheddar', 'roumi', 'feta']),
    ('four_cheese', 'طاسة أربعة أجبان', 'Four cheese pan', 'cheese', 130, 215,
     ['mozzarella', 'cheddar', 'parmesan', 'blue_cheese']),
    ('veggie', 'طاسة جبنة بالخضار', 'Cheese & veggie pan', 'cheese', 115, 190,
     ['mozzarella', 'mushroom', 'bell_pepper_green', 'onion', 'tomato',
      'olive_black']),
    ('sausage', 'طاسة جبنة بالسوسيس', 'Cheese & sausage pan', 'meat', 125,
     205, ['mozzarella', 'sausage', 'bell_pepper_green', 'tomato']),
    ('hot_dog', 'طاسة جبنة بالهوت دوج', 'Cheese & hot dog pan', 'meat', 120,
     200, ['mozzarella', 'cheddar', 'hot_dog']),
    ('smoked_turkey', 'طاسة جبنة بالتركي المدخن', 'Cheese & smoked turkey pan',
     'meat', 135, 225, ['mozzarella', 'roumi', 'smoked_turkey']),
    ('chicken', 'طاسة جبنة بالفراخ', 'Cheese & chicken pan', 'meat', 135, 225,
     ['mozzarella', 'chicken', 'mushroom', 'bell_pepper_red']),
    ('ground_beef', 'طاسة جبنة باللحمة المفرومة', 'Cheese & minced beef pan',
     'meat', 140, 230, ['mozzarella', 'ground_beef', 'onion',
                        'bell_pepper_green']),
    ('basterma', 'طاسة جبنة بالبسطرمة', 'Cheese & basterma pan', 'meat', 145,
     240, ['mozzarella', 'roumi', 'basterma']),
    ('tuna', 'طاسة جبنة بالتونة', 'Cheese & tuna pan', 'sea', 135, 225,
     ['mozzarella', 'tuna', 'corn', 'olive_black']),
]

# Shown on the home page after the pizza and the crepe.
CATEGORY_ORDER = 3

# The toppings' layout: spread evenly over the cheese (`even`) up to near
# the pan's inner wall, as full on every pan whatever its toppings. The
# base's `surface` (PAN_SURFACE) already keeps the whole layer inside the
# wall, so radii here are of the cheese, like the pizza's of its base.
TOPPING_LAYOUT = {'radius': 0.86, 'coverage': 0.55}
# The grated cheese and the herbs spread out to the wall.
CHEESE_RADIUS = 0.8

# How the pan goes into the oven (owner feedback): it slides into an oven
# placed fully on screen and bakes while its cheese melts and the toppings
# sink into it (`melt`, with the pieces captured apart: `pieces`), comes
# out melted, is covered with cellophane (`Cover`), and stays melted and
# covered through Swap and FlyToCart. Reduced motion: Swap and FlyToCart.
MELT = {'area': round(PAN_SURFACE * 0.97, 2), 'color': '#F0B648',
        'blur': 1.6, 'tint': 0.42, 'sink': 0.45}
COVER = {'area': 0.9, 'color': '#E8F2FA', 'opacity': 0.16, 'gloss': 0.75,
         'from': 'left'}
BAKED = {'pieces': True, 'melt': MELT}
ANIMATION = [
    {'step': 'SlideIntoOven', 'weight': 2000, 'params': {
        'durationMs': 2000, 'saturation': 1.35, 'insideScale': 0.62,
        'tilt': 0.6, 'archWidth': 0.95, 'shrinkTo': 0.9,
        # Melted cheese bubbling while it bakes.
        'bubbles': 22, 'bubbleArea': round(PAN_SURFACE * 0.95, 2),
        'scrimMaxPct': 35, **BAKED,
        'images': {'steam': 'oven_steam', 'embers': 'oven_embers'}}},
    {'step': 'Cover', 'weight': 600, 'params': {
        'durationMs': 600, 'scale': 0.9, 'scrimMaxPct': 35, **BAKED,
        'cover': COVER}},
    {'step': 'Swap', 'weight': 300, 'params': {
        'durationMs': 300, **BAKED, 'cover': COVER}},
    {'step': 'FlyToCart', 'weight': 900, 'params': {
        'durationMs': 900, 'shrinkTo': 0.18, 'arcControlPct': 20,
        'rotateDeg': -12, **BAKED, 'cover': COVER}},
]


def dump(path: str, data) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main() -> None:
    pizza_def = json.load(open('definitions/pizza.json', encoding='utf-8'))
    pizza_ing = {i['id']: i for i in json.load(
        open('tools/seed/pizza_ingredients.json', encoding='utf-8'))['ingredients']}
    new_ids = [i[0] for i in NEW_INGREDIENTS]
    shared = SHARED + SAUCE_IDS
    allowed = SHARED + new_ids + SAUCE_IDS
    assert all(s in pizza_ing for s in shared), set(shared) - set(pizza_ing)
    assert not set(new_ids) & set(pizza_ing)
    assert len(set(allowed)) == len(allowed)
    for pid, *_, single, sharing, defaults in PRODUCTS:
        assert set(defaults) <= set(allowed), (pid, set(defaults) - set(allowed))
        assert sharing > single, pid
    files = sorted(os.path.basename(f) for f in
                   glob.glob('assets_src/cheese_pan/ingredients/*.webp'))

    pp = pizza_def['placement']['params']
    params = {**TOPPING_LAYOUT, 'pieceSize': 0.13, 'piecesPerUnit': 9,
              'minGap': 0.16}
    # Shared ingredients keep the pizza's look (piece count, size, fill,
    # the grated cheese's and herbs' gaps); cheese and herbs reach the wall.
    for k in SHARED:
        for key in ('piecesPerUnit', 'pieceSize', 'fill', 'minGap'):
            if f'{key}:{k}' in pp:
                params[f'{key}:{k}'] = pp[f'{key}:{k}']
        if k in DRAWN_CHEESES or k in HERBS:
            params[f'radius:{k}'] = CHEESE_RADIUS
    for k, _, _, _, per, size, _ in NEW_INGREDIENTS:
        params[f'piecesPerUnit:{k}'] = per
        params[f'pieceSize:{k}'] = size
        params[f'fill:{k}'] = sprite_fill(
            f'assets_src/cheese_pan/ingredients/{f}' for f in files
            if re.fullmatch(rf'ing_{re.escape(k)}_\d+\.webp', f))
    params.update(sauce_params(SAUCES, SAUCE_ANGLES, SAUCE_POUR))
    cheeses = [k for k in SHARED if k in DRAWN_CHEESES]
    motion = {k: pizza_def['ingredientMotion'][k] for k in SHARED}
    for k, *_, enter in NEW_INGREDIENTS:
        motion[k] = {'enter': enter, 'exit': 'liftFade'}

    dump('definitions/cheese_pan.json', {
        'id': 'cheese_pan',
        'definitionVersion': 1,
        'name': 'طاسة جبنة',
        'names': {'en': 'Cheese pan', 'ar': 'طاسة جبنة'},
        # The toppings stay inside the pan's inner wall (`surface`).
        'base': {'shape': 'circle', 'rawAssetId': 'base_cheese_pan_raw',
                 'cookedAssetId': 'base_cheese_pan_cooked',
                 'surface': PAN_SURFACE},
        'allowedIngredientIds': allowed,
        # Like the pizza: the toppings spread together evenly (`even`), the
        # grated cheese under them and the herbs over them are layers of
        # their own (`scatter`), and the sauces are poured over everything.
        'placement': {'strategy': 'even', 'params': params,
                      'byIngredient': {**{k: 'scatter' for k in cheeses + HERBS},
                                       **{k: 'sauce' for k in SAUCE_IDS}}},
        'layerOverrides': {**{k: 10 for k in cheeses},
                           **{k: 30 for k in HERBS},
                           **{k: 40 for k in SAUCE_IDS}},
        'constraints': {'maxQty': 2},
        'sizes': [{'id': s, 'name': ar, 'names': {'en': en, 'ar': ar},
                   'scale': scale} for s, ar, en, scale in SIZES],
        'optionGroups': [],
        'animation': ANIMATION,
        'productGroups': [{'id': g, 'name': ar, 'names': {'en': en, 'ar': ar}}
                          for g, ar, en in GROUPS],
        # Every pan offers the sauces as extras, in a section of their own.
        'addOnGroups': [{'id': 'sauces', 'name': 'الصوصات',
                         'names': {'en': 'Sauces', 'ar': 'الصوصات'},
                         'ingredientIds': SAUCE_IDS}],
        'ingredientMotion': motion,
        'assetSpecs': pizza_def['assetSpecs'],
    })
    dump('definitions/cheese_pan.temp.json', {
        '_note': 'Calibration values, not owner data.',
        'tempFields': ['placement.params', 'ingredientMotion', 'animation'],
        'pendingNotes': [
            'The pan and the new ingredient images are drawn in code '
            '(tools/process_cheese_pan_assets.py) until photos exist.',
            'The baked pan (base.cookedAssetId) is not shown yet: the '
            'oven bakes the snapshot with the Cooked filter, like the pizza.',
        ],
    })

    ingredients = []
    for k, ar, en, extra, *_ in NEW_INGREDIENTS:
        variants = [f for f in files
                    if re.fullmatch(rf'ing_{re.escape(k)}_\d+\.webp', f)]
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': ar, 'names': {'en': en, 'ar': ar},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': extra * EGP, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/cheese_pan_ingredients.json', {
        '_note': 'Ingredients the cheese pan introduces. Every other '
                 'ingredient and sauce reuses the pizza records '
                 '(tools/seed/pizza_ingredients.json).',
        'ingredients': ingredients,
    })

    products = [{
        'id': f'cheese_pan_{pid}', 'categoryId': 'cheese_pan', 'name': ar,
        'names': {'en': en, 'ar': ar}, 'description': '',
        'basePrice': single * EGP, 'imageAssetId': f'final_cheese_pan_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults],
        'isAvailable': True,
        'sizeDeltas': {'single': 0, 'sharing': (sharing - single) * EGP},
        'optionDeltas': {},
        'displayOrder': i, 'groupId': group,
    } for i, (pid, ar, en, group, single, sharing, defaults)
        in enumerate(PRODUCTS)]
    dump('tools/seed/cheese_pan_products.json', {
        'temp': True,
        '_note': 'Market-estimate prices set by the developer at the owner\'s '
                 'request. temp marks the code-drawn images and missing final '
                 'product images.',
        'categoryOrder': CATEGORY_ORDER,
        'tempFields': ['defaults[].removable'],
        'products': products,
    })

    # Readable catalog: products, ingredients, extras and prices.
    names = {k: pizza_ing[k]['name'] for k in shared}
    names.update({k: ar for k, ar, *_ in NEW_INGREDIENTS})
    extra = {k: pizza_ing[k]['extraPrice'] // EGP for k in shared}
    extra.update({k: e for k, _, _, e, *_ in NEW_INGREDIENTS})
    gname = {g: ar for g, ar, _ in GROUPS}
    lines = [
        '# CHEESE_PAN_CATALOG.md — منيو طاسة الجبنة ومكوناتها وإضافاتها وأسعارها',
        '',
        '> **مُولَّد** من `tools/build_cheese_pan_catalog.py` (المصدر الوحيد). لا تعدّله يدوياً: عدّل السكربت ثم شغّله.',
        '> الأسعار تقديرات سوق مصري (بنها 2026) بتفويض المالك، بالجنيه، متسقة مع البيتزا والكريب. مقاسان: فردي ومشاركة. السعر الأساسي يشمل المكونات الافتراضية.',
        '',
        '## 1) المنتجات',
        '',
        '| # | الاسم | English | القسم | المكونات الافتراضية | فردي | مشاركة |',
        '| --- | --- | --- | --- | --- | --- | --- |',
    ]
    for i, (pid, ar, en, group, single, sharing, defaults) in enumerate(PRODUCTS, 1):
        lines.append(f'| {i} | {ar} | {en} | {gname[group]} | '
                     f'{"، ".join(names[d] for d in defaults)} | {single} ج | {sharing} ج |')
    lines += ['', '## 2) المكونات', '',
              '| المعرّف | الاسم | المصدر | الصورة |', '| --- | --- | --- | --- |']
    for k in SHARED + new_ids:
        src = 'جديد لطاسة الجبنة' if k in new_ids else 'مشترك مع البيتزا'
        img = ('مرسومة بالكود (3 تنويعات)' if k in new_ids
               else 'صور البيتزا الحالية')
        lines.append(f'| `{k}` | {names[k]} | {src} | {img} |')
    lines += ['', '## 3) الصوصات (إضافات)', '',
              '> صوصات البيتزا نفسها بنفس السعر والصورة، تُصب سائلة فوق الطاسة، في قسم «الصوصات» لكل الأصناف، حتى 2 فوق الافتراضي.',
              '', '| المعرّف | الاسم | السعر |', '| --- | --- | --- |']
    for k in SAUCE_IDS:
        lines.append(f'| `{k}` | {names[k]} | {extra[k]} ج |')
    lines += ['', '## 4) الإضافات وأسعارها', '',
              '> الإضافة تزيد كمية مكوّن، بحد أقصى 2 فوق الافتراضي (`maxQty`)، وبنفس السعر في المقاسين. سعر المكوّن المشترك هو نفسه في البيتزا والكريب والطاسة (مصدر واحد).',
              '', '| المكوّن | سعر الإضافة |', '| --- | --- |']
    for k in sorted(SHARED + new_ids, key=lambda x: (extra[x], names[x])):
        lines.append(f'| {names[k]} | {extra[k]} ج |')
    lines += ['', '## 5) ملخص الأسعار', '',
              '| القسم | أقل سعر (فردي) | أعلى سعر (فردي) | أقل سعر (مشاركة) | أعلى سعر (مشاركة) | عدد الأصناف |',
              '| --- | --- | --- | --- | --- | --- |']
    for g, ar, _ in GROUPS:
        ps = [p for p in PRODUCTS if p[3] == g]
        lines.append(f'| {ar} | {min(p[4] for p in ps)} ج | {max(p[4] for p in ps)} ج | '
                     f'{min(p[5] for p in ps)} ج | {max(p[5] for p in ps)} ج | {len(ps)} |')
    lines += ['', '## 6) الحركة', '',
              'الطاسة تنزلق داخل فتحة فرن (قوس) ظاهر كله على الشاشة، وتُخبز بين اللهب والجبن يسيح ويفور والمكونات تغوص فيه وتمتزج معه، ثم تخرج مسوّاة ويتصاعد منها البخار (`SlideIntoOven`)، ثم تُغطى بالسلوفان (`Cover`) وتبقى مغطاة في `Swap` و`FlyToCart`. مع «تقليل الحركة»: `Swap` ثم `FlyToCart` فقط (والطاسة سايحة ومغطاة).',
              '', '## 7) الصور', '',
              '| الملف | الوصف |', '| --- | --- |',
              '| `assets_src/cheese_pan/bases/base_cheese_pan_raw.webp` | طاسة حديد بجبن مبشور (قبل الفرن) |',
              '| `assets_src/cheese_pan/bases/base_cheese_pan_cooked.webp` | طاسة بجبن سايح ذهبي يفور (بعد الفرن) |',
              '| `assets_src/cheese_pan/ingredients/ing_<id>_0N.webp` | المكونات الجديدة، 3 تنويعات لكل مكوّن |',
              '', 'كل الصور مرسومة بالكود (`tools/process_cheese_pan_assets.py`) وتُستبدل بصور حقيقية بنفس الاسم دون تعديل كود. الفرن مرسوم بالكود داخل الخطوة، ويستخدم صورتي البخار والجمر الحاليتين.', '']
    Path('CHEESE_PAN_CATALOG.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'{len(allowed)} ingredients ({len(new_ids)} new), '
          f'{len(products)} products')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
