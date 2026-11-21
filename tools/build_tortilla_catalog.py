"""Generate the tortilla sandwich (wrap) definition, seed data and catalog.

Owner request: the tortilla sandwich now, with its products, ingredients,
prices, images and animation. Prices are Egyptian-market estimates (Banha,
2026) set by the developer at the owner's request, in line with the pizza
and crepe prices. One size.

Usage (from repo root): python tools/build_tortilla_catalog.py
Outputs: definitions/tortilla.json, definitions/tortilla.temp.json,
         tools/seed/tortilla_ingredients.json,
         tools/seed/tortilla_products.json,
         TORTILLA_CATALOG.md (readable: products, ingredients, extras, prices)

Shared ingredients and sauces keep their one record and image (pizza and
crepe seed files); only the new ingredients are defined here (images:
tools/process_tortilla_assets.py).
"""
import glob
import json
import os
import re
from pathlib import Path

from build_crepe_catalog import (CREPE_DENSITY, NEW_INGREDIENTS as CREPE_NEW,
                                 SWEET_SAUCES)
from build_pizza_catalog import (DRAWN_CHEESES, SAUCES as PIZZA_SAUCES,
                                 sauce_params, sprite_fill)

EGP = 100

# New ingredients the wrap introduces: id, Arabic, English, extra EGP,
# pieces per unit, piece size, enter motion.
NEW_INGREDIENTS = [
    ('lettuce', 'خس', 'Lettuce', 5, 10, 0.16, 'shower'),
    ('pickles', 'مخلل', 'Pickles', 5, 7, 0.13, 'drop'),
    ('fries', 'بطاطس', 'Fries', 15, 6, 0.17, 'toss'),
    ('chicken_shawarma', 'شاورما فراخ', 'Chicken shawarma', 40, 7, 0.15,
     'shower'),
    ('beef_shawarma', 'شاورما لحمة', 'Beef shawarma', 50, 7, 0.15, 'shower'),
    ('crispy_chicken', 'فراخ كرسبي', 'Crispy chicken', 40, 5, 0.16, 'toss'),
]
NEW_IDS = [i[0] for i in NEW_INGREDIENTS]

# Reused savoury ingredients (pizza records, same price and image).
SHARED = [
    'mozzarella', 'cheddar', 'roumi', 'chicken', 'ground_beef', 'sausage',
    'tuna', 'mushroom', 'bell_pepper_green', 'bell_pepper_red', 'onion',
    'tomato', 'corn', 'olive_black', 'jalapeno',
]
# Reused sweet ingredients (crepe records).
SWEET_SHARED = ['banana', 'strawberry', 'lotus']

# The pizza's savoury sauces (pesto stays a pizza sauce) and the crepe's
# sweet sauces, each poured at its own angle across the filling strip
# (near-upright passes, like the crepe: the strip is narrow).
SAVORY_SAUCES = [x for x in PIZZA_SAUCES if x[0] != 'pesto_sauce']
SAVORY_SAUCE_ANGLES = [60, 120, 84, 72, 108, 48, 132, 96]
SWEET_SAUCE_ANGLES = [48, 132, 94, 77, 103, 68, 112, 86]
SAUCE_POUR = {'lines': 9, 'lineWidth': 0.04, 'wave': 0.005}
SAVORY_SAUCE_IDS = [x[0] for x in SAVORY_SAUCES]
SWEET_SAUCE_IDS = [x[0] for x in SWEET_SAUCES]
SAUCE_IDS = SAVORY_SAUCE_IDS + SWEET_SAUCE_IDS

# Extras any savoury wrap may add (owner: like a sandwich shop's extras).
SAVORY_EXTRAS = ['fries', 'cheddar', 'pickles', 'lettuce', 'jalapeno']

GROUPS = [('savory', 'تورتيلا حادق', 'Savoury wraps'),
          ('sweet', 'تورتيلا حلو', 'Sweet wraps')]

# id, Arabic, English, group, price EGP, default ingredients.
PRODUCTS = [
    ('chicken', 'تورتيلا فراخ', 'Grilled chicken wrap', 'savory', 110,
     ['chicken', 'lettuce', 'tomato', 'mayonnaise']),
    ('chicken_shawarma', 'تورتيلا شاورما فراخ', 'Chicken shawarma wrap',
     'savory', 105, ['chicken_shawarma', 'fries', 'pickles', 'garlic_sauce']),
    ('beef_shawarma', 'تورتيلا شاورما لحمة', 'Beef shawarma wrap', 'savory',
     135, ['beef_shawarma', 'onion', 'tomato', 'pickles']),
    ('crispy', 'تورتيلا كرسبي', 'Crispy chicken wrap', 'savory', 120,
     ['crispy_chicken', 'lettuce', 'tomato', 'ranch_sauce']),
    ('fajita', 'تورتيلا فاهيتا', 'Chicken fajita wrap', 'savory', 125,
     ['chicken', 'bell_pepper_green', 'bell_pepper_red', 'onion',
      'mozzarella']),
    ('minced_beef', 'تورتيلا لحمة مفرومة', 'Minced beef wrap', 'savory', 120,
     ['ground_beef', 'onion', 'bell_pepper_green', 'cheddar']),
    ('sausage', 'تورتيلا سجق', 'Sausage wrap', 'savory', 100,
     ['sausage', 'onion', 'bell_pepper_green', 'tomato']),
    ('tuna', 'تورتيلا تونة', 'Tuna wrap', 'savory', 110,
     ['tuna', 'corn', 'lettuce', 'mayonnaise']),
    ('mixed_cheese', 'تورتيلا مشكل جبن', 'Mixed cheese wrap', 'savory', 95,
     ['mozzarella', 'cheddar', 'roumi', 'tomato']),
    ('nutella_banana', 'تورتيلا نوتيلا وموز', 'Nutella & banana wrap', 'sweet',
     90, ['nutella', 'banana']),
    ('lotus', 'تورتيلا لوتس', 'Lotus wrap', 'sweet', 95,
     ['lotus', 'lotus_sauce']),
]

# Shown on the home page after the pizza and the crepe.
CATEGORY_ORDER = 2

# Where the filling goes on the round tortilla: a strip across its lower
# middle (the bottom edge is rolled over it first), `bandWidth` high around
# `offsetY`, inside `radius` (of the base radius). In box fractions that is
# FILLING_BOX below; the sides fold over its ends.
FILLING = {'radius': 0.5, 'bandWidth': 0.2, 'offsetY': 0.15}
FILLING_LAYOUT = {'inset': 0, 'coverage': 0.55}
FILLING_BOX = [0.25, 0.475, 0.75, 0.675]

# Animation shapes, in fractions of the product box. The left and right
# sides fold in over the ends of the filling (Fold, each line folds the part
# on its outer side), then the tortilla rolls up from its bottom edge into a
# log (Roll), which settles, larger, across the middle and is served half in
# paper.
SIDES = [[0.2, 1, 0.2, 0], [0.8, 0, 0.8, 1]]
ROLL = {
    # The folded sheet rolled up: from its bottom edge to its top.
    'area': [0.2, 0.03, 0.8, 0.97],
    # The finished log's diameter (of the box height).
    'thickness': 0.2,
    # Where the finished log settles (same proportions, grown 1.4x).
    'log': [0.08, 0.36, 0.92, 0.64],
    # The filling seen at the log's open end.
    'contents': FILLING_BOX,
}
SERVED = {**ROLL, 'sleeve': '#D9CCB0'}


def dump(path: str, data) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main() -> None:
    pizza_def = json.load(open('definitions/pizza.json', encoding='utf-8'))
    crepe_def = json.load(open('definitions/crepe.json', encoding='utf-8'))
    records = {}
    for f in ('pizza', 'crepe'):
        for i in json.load(open(f'tools/seed/{f}_ingredients.json',
                                encoding='utf-8'))['ingredients']:
            records[i['id']] = i
    shared = SHARED + SWEET_SHARED + SAUCE_IDS
    assert all(s in records for s in shared), set(shared) - set(records)
    assert not set(NEW_IDS) & set(records), set(NEW_IDS) & set(records)
    allowed = SHARED + NEW_IDS + SAVORY_SAUCE_IDS + SWEET_SHARED + SWEET_SAUCE_IDS
    for pid, *_, defaults in PRODUCTS:
        assert set(defaults) <= set(allowed), (pid, set(defaults) - set(allowed))
    f = FILLING
    assert FILLING_BOX == [
        round((1 - f['radius']) / 2, 3), round((1 + f['offsetY'] - f['bandWidth']) / 2, 3),
        round((1 + f['radius']) / 2, 3), round((1 + f['offsetY'] + f['bandWidth']) / 2, 3)]
    files = sorted(os.path.basename(p) for p in
                   glob.glob('assets_src/tortilla/ingredients/*.webp'))

    pp = pizza_def['placement']['params']
    cp = crepe_def['placement']['params']
    params = {'pieceSize': 0.12, 'piecesPerUnit': 12, **FILLING,
              **FILLING_LAYOUT, 'minGap': 0.1}
    # Shared pieces: as on the pizza, fewer of them (a smaller filling area;
    # `coverage` rescales the `even` fillings anyway), like the crepe.
    for k in SHARED:
        if f'piecesPerUnit:{k}' in pp:
            params[f'piecesPerUnit:{k}'] = max(
                3, round(pp[f'piecesPerUnit:{k}'] * CREPE_DENSITY))
        for key in ('pieceSize', 'fill'):
            if f'{key}:{k}' in pp:
                params[f'{key}:{k}'] = pp[f'{key}:{k}']
    for k in SWEET_SHARED:
        for key in ('piecesPerUnit', 'pieceSize', 'fill'):
            params[f'{key}:{k}'] = cp[f'{key}:{k}']
    for k, _, _, _, per, size, _ in NEW_INGREDIENTS:
        params[f'piecesPerUnit:{k}'] = per
        params[f'pieceSize:{k}'] = size
        params[f'fill:{k}'] = sprite_fill(
            f'assets_src/tortilla/ingredients/{p}' for p in files
            if re.fullmatch(rf'ing_{re.escape(k)}_\d+\.webp', p))
    params.update(sauce_params(SAVORY_SAUCES, SAVORY_SAUCE_ANGLES, SAUCE_POUR))
    params.update(sauce_params(SWEET_SAUCES, SWEET_SAUCE_ANGLES, SAUCE_POUR))
    cheeses = [k for k in SHARED if k in DRAWN_CHEESES]

    motion = {}
    for k in SHARED:
        if k in pizza_def['ingredientMotion']:
            motion[k] = pizza_def['ingredientMotion'][k]
    for k in SWEET_SHARED:
        motion[k] = crepe_def['ingredientMotion'][k]
    for k, *_, enter in NEW_INGREDIENTS:
        motion[k] = {'enter': enter,
                     'exit': 'dissolve' if enter == 'shower' else 'liftFade'}

    # `pieces`: the steps get the filling's pieces apart from the tortilla,
    # so the sides push them in as they fold over, and the roll gathers them
    # and takes them in as it passes.
    sides = {'lines': SIDES, 'volume': 0, 'pieces': True}
    dump('definitions/tortilla.json', {
        'id': 'tortilla',
        'definitionVersion': 1,
        'name': 'ساندوتش تورتيلا',
        'names': {'en': 'Tortilla wraps', 'ar': 'ساندوتش تورتيلا'},
        'base': {'shape': 'circle', 'rawAssetId': 'base_tortilla_raw',
                 'cookedAssetId': 'base_tortilla_cooked'},
        'allowedIngredientIds': allowed,
        # The fillings spread together evenly over the strip (`even`), the
        # grated cheese a layer of its own under them, the sauces poured
        # over them, like the crepe.
        'placement': {'strategy': 'even', 'params': params,
                      'byIngredient': {**{k: 'band' for k in cheeses},
                                       **{k: 'sauce' for k in SAUCE_IDS}}},
        # Lettuce lies under the fillings, the cheese under it.
        'layerOverrides': {**{k: 10 for k in cheeses}, 'lettuce': 15,
                           **{k: 40 for k in SAUCE_IDS}},
        'constraints': {'maxQty': 2},
        'sizes': [],
        'optionGroups': [],
        # The tortilla warms on the griddle, its sides fold in over the ends
        # of the filling (flat: `volume` 0), it rolls up from its bottom edge
        # into a log (its outside, role `back`, showing as it turns), and is
        # served half in paper. Image roles: surface (griddle), steam, back.
        'animation': [
            {'step': 'Griddle', 'weight': 800, 'params': {
                'durationMs': 800, 'saturation': 1.15,
                'images': {'surface': 'griddle_surface',
                           'steam': 'oven_steam'}}},
            {'step': 'Fold', 'weight': 450, 'params': {
                'durationMs': 450, 'stage': 1, **sides,
                'images': {'surface': 'griddle_surface',
                           'back': 'tortilla_back'}}},
            {'step': 'Fold', 'weight': 450, 'params': {
                'durationMs': 450, 'stage': 2, **sides,
                'images': {'surface': 'griddle_surface',
                           'back': 'tortilla_back'}}},
            {'step': 'Roll', 'weight': 1000, 'params': {
                # Served at its end: its paper comes on as it is lifted off.
                'durationMs': 1000, 'folds': 2, 'lines': SIDES,
                'roll': SERVED, 'pieces': True,
                'images': {'surface': 'griddle_surface',
                           'back': 'tortilla_back'}}},
            {'step': 'Swap', 'weight': 300, 'params': {
                'durationMs': 300, 'folds': 2, 'lines': SIDES, 'roll': SERVED,
                'images': {'back': 'tortilla_back'}}},
            {'step': 'Shrink', 'weight': 300, 'params': {
                'durationMs': 300, 'folds': 2, 'lines': SIDES, 'roll': SERVED,
                'shrinkTo': 0.85, 'scrimMaxPct': 0,
                'images': {'back': 'tortilla_back'}}},
            {'step': 'FlyToCart', 'weight': 750, 'params': {
                'durationMs': 750, 'folds': 2, 'lines': SIDES, 'roll': SERVED,
                'shrinkTo': 0.2, 'arcControlPct': 20, 'rotateDeg': -12,
                'images': {'back': 'tortilla_back'}}},
        ],
        'productGroups': [{'id': g, 'name': ar, 'names': {'en': en, 'ar': ar}}
                          for g, ar, en in GROUPS],
        'addOnGroups': [
            {'id': 'savory_sauces', 'name': 'الصوصات',
             'names': {'en': 'Sauces', 'ar': 'الصوصات'},
             'ingredientIds': SAVORY_SAUCE_IDS, 'productGroupIds': ['savory']},
            {'id': 'savory_extras', 'name': 'إضافات',
             'names': {'en': 'Extras', 'ar': 'إضافات'},
             'ingredientIds': SAVORY_EXTRAS, 'productGroupIds': ['savory']},
            {'id': 'sweet_sauces', 'name': 'الصوصات',
             'names': {'en': 'Sauces', 'ar': 'الصوصات'},
             'ingredientIds': SWEET_SAUCE_IDS, 'productGroupIds': ['sweet']},
        ],
        'ingredientMotion': motion,
        'assetSpecs': pizza_def['assetSpecs'],
    })
    dump('definitions/tortilla.temp.json', {
        '_note': 'Calibration values, not owner data.',
        'tempFields': ['placement.params', 'ingredientMotion', 'animation'],
        'pendingNotes': [
            'The tortilla, its outside and the new ingredient images are '
            'drawn in code (tools/process_tortilla_assets.py) until photos '
            'exist.',
        ],
    })

    ingredients = []
    for k, ar, en, extra, *_ in NEW_INGREDIENTS:
        variants = [p for p in files
                    if re.fullmatch(rf'ing_{re.escape(k)}_\d+\.webp', p)]
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': ar, 'names': {'en': en, 'ar': ar},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': extra * EGP, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/tortilla_ingredients.json', {
        '_note': 'Ingredients the tortilla wrap introduces. Shared fillings '
                 'and sauces reuse the pizza and crepe records.',
        'ingredients': ingredients,
    })

    products = [{
        'id': f'tortilla_{pid}', 'categoryId': 'tortilla', 'name': ar,
        'names': {'en': en, 'ar': ar}, 'description': '',
        'basePrice': price * EGP, 'imageAssetId': f'final_tortilla_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults],
        'isAvailable': True, 'sizeDeltas': {}, 'optionDeltas': {},
        'displayOrder': i, 'groupId': group,
    } for i, (pid, ar, en, group, price, defaults) in enumerate(PRODUCTS)]
    dump('tools/seed/tortilla_products.json', {
        'temp': True,
        '_note': 'Market-estimate prices set by the developer at the '
                 "owner's request. temp marks the code-drawn images and "
                 'missing final product images.',
        'categoryOrder': CATEGORY_ORDER,
        'tempFields': ['defaults[].removable'],
        'products': products,
    })

    write_catalog(records, allowed)
    print(f'{len(allowed)} ingredients ({len(NEW_IDS)} new), '
          f'{len(products)} products')


def write_catalog(records, allowed) -> None:
    names = {k: records[k]['name'] for k in records}
    names.update({k: ar for k, ar, *_ in NEW_INGREDIENTS})
    extra = {k: records[k]['extraPrice'] // EGP for k in records}
    extra.update({k: e for k, _, _, e, *_ in NEW_INGREDIENTS})
    gname = {g: ar for g, ar, _ in GROUPS}
    lines = [
        '# TORTILLA_CATALOG.md — منيو ساندوتش التورتيلا ومكوناته وإضافاته وأسعاره',
        '',
        '> **مُولَّد** من `tools/build_tortilla_catalog.py` (المصدر الوحيد). لا تعدّله يدوياً: عدّل السكربت ثم شغّله.',
        '> الأسعار تقديرات سوق مصري (بنها 2026) بتفويض المالك، بالجنيه، ومتسقة مع أسعار البيتزا والكريب. حجم واحد. السعر الأساسي يشمل المكونات الافتراضية.',
        '',
        '## 1) المنتجات',
        '',
        '| # | الاسم | English | القسم | المكونات الافتراضية | السعر |',
        '| --- | --- | --- | --- | --- | --- |',
    ]
    for i, (pid, ar, en, group, price, defaults) in enumerate(PRODUCTS, 1):
        lines.append(f'| {i} | {ar} | {en} | {gname[group]} | '
                     f'{"، ".join(names[d] for d in defaults)} | {price} ج |')
    lines += ['', '## 2) المكونات', '',
              '| المعرّف | الاسم | المصدر | الصورة |', '| --- | --- | --- | --- |']
    for k in SHARED + SWEET_SHARED + NEW_IDS:
        if k in NEW_IDS:
            src, img = 'جديد للتورتيلا', 'مرسومة بالكود (3 تنويعات)'
        elif k in SWEET_SHARED:
            src, img = 'مشترك مع الكريب', 'صور الكريب الحالية'
        else:
            src, img = 'مشترك مع البيتزا', 'صور البيتزا الحالية'
        lines.append(f'| `{k}` | {names[k]} | {src} | {img} |')
    lines += ['', '## 3) الصوصات والإضافات (أقسام الإضافة)', '',
              '> الصوصات تُصب سائلة فوق الحشو. الحادق يظهر للتورتيلا الحادق والحلو للحلو، وقسم «إضافات» للحادق. كل إضافة حتى 2 فوق الافتراضي. الصوص والمكوّن المشترك بنفس سعره في البيتزا والكريب.',
              '', '| المعرّف | الاسم | القسم | يُعرض مع | السعر |',
              '| --- | --- | --- | --- | --- |']
    for k in SAVORY_SAUCE_IDS:
        lines.append(f'| `{k}` | {names[k]} | الصوصات | التورتيلا الحادق | {extra[k]} ج |')
    for k in SAVORY_EXTRAS:
        lines.append(f'| `{k}` | {names[k]} | إضافات | التورتيلا الحادق | {extra[k]} ج |')
    for k in SWEET_SAUCE_IDS:
        lines.append(f'| `{k}` | {names[k]} | الصوصات | التورتيلا الحلو | {extra[k]} ج |')
    lines += ['', '## 4) أسعار الإضافة لكل مكوّن', '',
              '> الإضافة تزيد كمية مكوّن في المنتج، بحد أقصى 2 فوق الافتراضي (`maxQty`).',
              '', '| المكوّن | سعر الإضافة |', '| --- | --- |']
    for k in sorted([k for k in allowed if k not in SAUCE_IDS],
                    key=lambda x: (extra[x], names[x])):
        lines.append(f'| {names[k]} | {extra[k]} ج |')
    lines += ['', '## 5) ملخص الأسعار', '',
              '| القسم | أقل سعر | أعلى سعر | عدد الأصناف |',
              '| --- | --- | --- | --- |']
    for g, ar, _ in GROUPS:
        ps = [p[4] for p in PRODUCTS if p[3] == g]
        lines.append(f'| {ar} | {min(ps)} ج | {max(ps)} ج | {len(ps)} |')
    lines += ['', '## 6) الصور', '',
              '| الملف | الوصف |', '| --- | --- |',
              '| `assets_src/tortilla/bases/base_tortilla_raw.webp` | تورتيلا كما هي |',
              '| `assets_src/tortilla/bases/base_tortilla_cooked.webp` | تورتيلا محمّصة خفيفاً |',
              '| `assets_src/animation/tortilla_back.webp` | الوجه الخارجي (يظهر على اللفة في حركة Roll) |',
              '| `assets_src/tortilla/ingredients/ing_<id>_0N.webp` | المكونات الجديدة، 3 تنويعات لكل مكوّن |',
              '', 'كل الصور مرسومة بالكود (`tools/process_tortilla_assets.py`) وتُستبدل بصور حقيقية بنفس الاسم دون تعديل كود. سطح الجريل والبخار مشتركان مع الكريب والبيتزا.',
              '', '## 7) الحركة', '',
              'جريل (تسخين) ← طي الجانبين (Fold ×2) ← لف من الحافة السفلية (Roll) ← Swap ← Shrink ← FlyToCart، نحو 4 ثوانٍ. مع «تقليل الحركة»: Swap ثم FlyToCart فقط، والساندوتش ملفوف.', '']
    Path('TORTILLA_CATALOG.md').write_text('\n'.join(lines), encoding='utf-8')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
