"""Generate the crepe definition, seed data and catalog document.

Prices are Egyptian-market estimates (Banha, 2026) set by the developer at
the owner's request ("start the crepe at market prices"). One size.

Usage (from repo root): python tools/build_crepe_catalog.py
Outputs: definitions/crepe.json, definitions/crepe.temp.json,
         tools/seed/crepe_ingredients.json, tools/seed/crepe_products.json,
         CREPE_CATALOG.md (readable: products, ingredients, extras, prices)

Savoury crepes reuse the pizza ingredients (one record and one image per
ingredient, defined in tools/seed/pizza_ingredients.json); only the new
sweet ingredients are defined here (images: tools/process_crepe_assets.py).
"""
import glob
import json
import os
from pathlib import Path

EGP = 100

# New ingredients introduced by the crepe: id, Arabic, English, extra EGP,
# pieces per unit, piece size, enter motion.
NEW_INGREDIENTS = [
    ('nutella', 'نوتيلا', 'Nutella', 20, 5, 0.2, 'drop'),
    ('white_chocolate', 'شوكولاتة بيضاء', 'White chocolate', 20, 3, 0.24, 'drop'),
    ('lotus', 'لوتس', 'Lotus', 25, 6, 0.16, 'sprinkle'),
    ('banana', 'موز', 'Banana', 10, 8, 0.12, 'toss'),
    ('strawberry', 'فراولة', 'Strawberry', 15, 7, 0.13, 'toss'),
]

# Reused pizza ingredients the crepe allows (savoury fillings).
SHARED = [
    'mozzarella', 'cheddar', 'roumi', 'feta', 'chicken', 'ground_beef',
    'sausage', 'basterma', 'tuna', 'mortadella', 'shrimp', 'mushroom',
    'bell_pepper_green', 'onion', 'tomato', 'corn', 'olive_black', 'garlic',
]

GROUPS = [('savory', 'كريب حادق', 'Savoury crepes'),
          ('sweet', 'كريب حلو', 'Sweet crepes')]

# id, Arabic, English, group, price EGP, default ingredients.
PRODUCTS = [
    ('chicken', 'كريب فراخ', 'Chicken crepe', 'savory', 115,
     ['chicken', 'mozzarella', 'bell_pepper_green']),
    ('chicken_mushroom', 'كريب فراخ ومشروم', 'Chicken & mushroom crepe',
     'savory', 125, ['chicken', 'mushroom', 'mozzarella']),
    ('meat', 'كريب لحمة', 'Minced beef crepe', 'savory', 125,
     ['ground_beef', 'mozzarella', 'onion', 'bell_pepper_green']),
    ('sausage', 'كريب سجق', 'Sausage crepe', 'savory', 105,
     ['sausage', 'mozzarella', 'tomato']),
    ('basterma', 'كريب بسطرمة', 'Basterma crepe', 'savory', 135,
     ['basterma', 'mozzarella', 'roumi']),
    ('tuna', 'كريب تونة', 'Tuna crepe', 'savory', 115,
     ['tuna', 'mozzarella', 'corn', 'olive_black']),
    ('mixed_cheese', 'كريب مشكل جبن', 'Mixed cheese crepe', 'savory', 100,
     ['mozzarella', 'cheddar', 'roumi', 'feta']),
    ('mortadella', 'كريب رومي ومرتديلا', 'Roumi & mortadella crepe', 'savory',
     95, ['mortadella', 'roumi', 'mozzarella']),
    ('shrimp', 'كريب جمبري', 'Shrimp crepe', 'savory', 160,
     ['shrimp', 'mozzarella', 'garlic']),
    ('nutella', 'كريب نوتيلا', 'Nutella crepe', 'sweet', 85, ['nutella']),
    ('nutella_banana', 'كريب نوتيلا وموز', 'Nutella & banana crepe', 'sweet',
     95, ['nutella', 'banana']),
    ('nutella_strawberry', 'كريب نوتيلا وفراولة', 'Nutella & strawberry crepe',
     'sweet', 100, ['nutella', 'strawberry']),
    ('lotus', 'كريب لوتس', 'Lotus crepe', 'sweet', 95, ['lotus']),
    ('lotus_banana', 'كريب لوتس وموز', 'Lotus & banana crepe', 'sweet', 105,
     ['lotus', 'banana']),
    ('two_chocolates', 'كريب شوكولاتتين', 'Two chocolates crepe', 'sweet', 100,
     ['nutella', 'white_chocolate']),
    ('fruit', 'كريب فواكه بالنوتيلا', 'Fruit & Nutella crepe', 'sweet', 110,
     ['nutella', 'banana', 'strawberry']),
]

# Sauces drizzled in lines over the filling: id, pieces per unit, size.
DRIZZLED = [('nutella', 48, 0.085), ('white_chocolate', 27, 0.12)]

# Fold lines of the cone, in fractions of the product box: each folds the
# part on its outer side (left, then right) over the filling. They meet
# near the bottom and open towards the top, where the filling shows.
CONE = [[0.36, 0.77, 0.16, 0.25], [0.84, 0.25, 0.64, 0.77]]
# The open top of the cone, between the fold lines down to the middle of the
# filling: the inside (and the filling) shows there over the folds.
REVEAL = [[0.16, 0.25], [0.84, 0.25], [0.692, 0.64], [0.308, 0.64]]

# Shown on the home page after the pizza.
CATEGORY_ORDER = 1


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
    allowed = SHARED + new_ids
    assert all(s in pizza_ing for s in SHARED), set(SHARED) - set(pizza_ing)
    for pid, *_, defaults in PRODUCTS:
        assert set(defaults) <= set(allowed), (pid, set(defaults) - set(allowed))
    files = sorted(os.path.basename(f) for f in
                   glob.glob('assets_src/crepe/ingredients/*.webp'))

    pp = pizza_def['placement']['params']
    # Fillings lie in a band across the middle (where the crepe is folded
    # over them); chocolate sauces are drizzled in lines (P2-04).
    # The crepe is a half moon (owner request): curved side up, straight
    # edge at 3/4 of the height. The filling sits in its middle (offsetY),
    # in a short band, with the sauces drizzled over it.
    params = {'pieceSize': 0.12, 'piecesPerUnit': 7, 'radius': 0.42,
              'bandWidth': 0.13, 'offsetY': 0.16, 'minGap': 0.09,
              'lines': 2, 'wave': 0.035}
    for k in SHARED:
        for p in ('piecesPerUnit', 'pieceSize'):
            if f'{p}:{k}' in pp:
                params[f'{p}:{k}'] = pp[f'{p}:{k}']
    for k, _, _, _, per, size, _ in NEW_INGREDIENTS:
        params[f'piecesPerUnit:{k}'] = per
        params[f'pieceSize:{k}'] = size
    for k, per, size in DRIZZLED:
        params[f'piecesPerUnit:{k}'] = per
        params[f'pieceSize:{k}'] = size
    motion = {k: pizza_def['ingredientMotion'][k] for k in SHARED
              if k in pizza_def['ingredientMotion']}
    for k, *_, enter in NEW_INGREDIENTS:
        motion[k] = {'enter': enter, 'exit': 'liftFade'}

    dump('definitions/crepe.json', {
        'id': 'crepe',
        'definitionVersion': 1,
        'name': 'كريب',
        'names': {'en': 'Crepe', 'ar': 'كريب'},
        'base': {'shape': 'circle', 'rawAssetId': 'base_crepe_raw',
                 'cookedAssetId': 'base_crepe_cooked'},
        'allowedIngredientIds': allowed,
        'placement': {'strategy': 'band', 'params': params,
                      'byIngredient': {k: 'drizzle' for k, *_ in DRIZZLED}},
        'constraints': {'maxQty': 2},
        'sizes': [],
        'optionGroups': [],
        # P2-07 (owner request): the half moon cooks on the griddle, then
        # its left and right sides fold over the filling into a cone, the
        # filling showing at the open top. Image roles: surface (griddle),
        # steam, back (the browned outside of a folded part).
        'animation': [
            {'step': 'Griddle', 'weight': 1100, 'params': {
                'durationMs': 1100, 'saturation': 1.25,
                'images': {'surface': 'griddle_surface',
                           'steam': 'oven_steam'}}},
            {'step': 'Fold', 'weight': 650, 'params': {
                'durationMs': 650, 'stage': 1, 'lines': CONE, 'reveal': REVEAL,
                'images': {'surface': 'griddle_surface',
                           'back': 'crepe_back'}}},
            {'step': 'Fold', 'weight': 650, 'params': {
                'durationMs': 650, 'stage': 2, 'lines': CONE, 'reveal': REVEAL,
                'images': {'surface': 'griddle_surface',
                           'back': 'crepe_back'}}},
            {'step': 'Swap', 'weight': 300, 'params': {
                'durationMs': 300, 'folds': 2, 'lines': CONE, 'reveal': REVEAL,
                'images': {'back': 'crepe_back'}}},
            {'step': 'Shrink', 'weight': 350, 'params': {
                'durationMs': 350, 'folds': 2, 'lines': CONE, 'reveal': REVEAL,
                'shrinkTo': 0.85,
                'images': {'back': 'crepe_back',
                           'surface': 'griddle_surface'}}},
            {'step': 'FlyToCart', 'weight': 800, 'params': {
                'durationMs': 800, 'folds': 2, 'lines': CONE, 'reveal': REVEAL,
                'shrinkTo': 0.2, 'arcControlPct': 20, 'rotateDeg': -12,
                'images': {'back': 'crepe_back'}}},
        ],
        'productGroups': [{'id': g, 'name': ar, 'names': {'en': en, 'ar': ar}}
                          for g, ar, en in GROUPS],
        'ingredientMotion': motion,
        'assetSpecs': pizza_def['assetSpecs'],
    })
    dump('definitions/crepe.temp.json', {
        '_note': 'Calibration values, not owner data.',
        'tempFields': ['placement.params', 'ingredientMotion', 'animation'],
        'pendingNotes': [
            'Bases and sweet ingredient images are drawn in code '
            '(tools/process_crepe_assets.py) until photos exist.',
        ],
    })

    ingredients = []
    for k, ar, en, extra, *_ in NEW_INGREDIENTS:
        variants = [f for f in files if f.startswith(f'ing_{k}_')]
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': ar, 'names': {'en': en, 'ar': ar},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': extra * EGP, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/crepe_ingredients.json', {
        '_note': 'Ingredients the crepe introduces. Savoury fillings reuse '
                 'the pizza records (tools/seed/pizza_ingredients.json).',
        'ingredients': ingredients,
    })

    products = [{
        'id': f'crepe_{pid}', 'categoryId': 'crepe', 'name': ar,
        'names': {'en': en, 'ar': ar}, 'description': '',
        'basePrice': price * EGP, 'imageAssetId': f'final_crepe_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults],
        'isAvailable': True, 'sizeDeltas': {}, 'optionDeltas': {},
        'displayOrder': i, 'groupId': group,
    } for i, (pid, ar, en, group, price, defaults) in enumerate(PRODUCTS)]
    dump('tools/seed/crepe_products.json', {
        'temp': True,
        '_note': 'Market-estimate prices approved by the owner. temp marks '
                 'the code-drawn images and missing final product images.',
        'categoryOrder': CATEGORY_ORDER,
        'tempFields': ['defaults[].removable'],
        'products': products,
    })

    # Readable catalog: products, ingredients, extras and prices.
    names = {k: pizza_ing[k]['name'] for k in SHARED}
    names.update({k: ar for k, ar, *_ in NEW_INGREDIENTS})
    extra = {k: pizza_ing[k]['extraPrice'] // EGP for k in SHARED}
    extra.update({k: e for k, _, _, e, *_ in NEW_INGREDIENTS})
    lines = [
        '# CREPE_CATALOG.md — منيو الكريب ومكوناته وإضافاته وأسعاره',
        '',
        '> **مُولَّد** من `tools/build_crepe_catalog.py` (المصدر الوحيد). لا تعدّله يدوياً: عدّل السكربت ثم شغّله.',
        '> الأسعار تقديرات سوق مصري (بنها 2026) بتفويض المالك، بالجنيه. حجم واحد. السعر الأساسي يشمل المكونات الافتراضية.',
        '',
        '## 1) المنتجات',
        '',
        '| # | الاسم | English | القسم | المكونات الافتراضية | السعر |',
        '| --- | --- | --- | --- | --- | --- |',
    ]
    gname = {g: ar for g, ar, _ in GROUPS}
    for i, (pid, ar, en, group, price, defaults) in enumerate(PRODUCTS, 1):
        lines.append(f'| {i} | {ar} | {en} | {gname[group]} | '
                     f'{"، ".join(names[d] for d in defaults)} | {price} ج |')
    lines += ['', '## 2) المكونات', '',
              '| المعرّف | الاسم | المصدر | الصورة |', '| --- | --- | --- | --- |']
    for k in allowed:
        src = 'جديد للكريب' if k in new_ids else 'مشترك مع البيتزا'
        img = ('مرسومة بالكود (3 تنويعات)' if k in new_ids
               else 'صور البيتزا الحالية')
        lines.append(f'| `{k}` | {names[k]} | {src} | {img} |')
    lines += ['', '## 3) الإضافات وأسعارها', '',
              '> الإضافة تزيد كمية مكوّن موجود في المنتج، بحد أقصى 2 فوق الافتراضي (`maxQty`). سعر المكوّن المشترك هو نفسه في البيتزا والكريب (مصدر واحد).',
              '', '| المكوّن | سعر الإضافة |', '| --- | --- |']
    for k in sorted(allowed, key=lambda x: (extra[x], names[x])):
        lines.append(f'| {names[k]} | {extra[k]} ج |')
    lines += ['', '## 4) ملخص الأسعار', '',
              '| القسم | أقل سعر | أعلى سعر | عدد الأصناف |',
              '| --- | --- | --- | --- |']
    for g, ar, _ in GROUPS:
        ps = [p[4] for p in PRODUCTS if p[3] == g]
        lines.append(f'| {ar} | {min(ps)} ج | {max(ps)} ج | {len(ps)} |')
    lines += ['', '## 5) الصور', '',
              '| الملف | الوصف |', '| --- | --- |',
              '| `assets_src/crepe/bases/base_crepe_raw.webp` | عجينة نيئة |',
              '| `assets_src/crepe/bases/base_crepe_cooked.webp` | كريب مسوّى (بعد الجريل) |',
              '| `assets_src/animation/crepe_back.webp` | ظهر الكريب (الوجه الخارجي بعد الطي، P2-06) |',
              '| `assets_src/animation/griddle_surface.webp` | سطح الجريل (لحركة الجريل P2-05) |',
              '| `assets_src/crepe/ingredients/ing_<id>_0N.webp` | المكونات الحلوة الجديدة، 3 تنويعات لكل مكوّن |',
              '', 'كل الصور مرسومة بالكود (`tools/process_crepe_assets.py`) وتُستبدل بصور حقيقية بنفس الاسم دون تعديل كود.', '']
    Path('CREPE_CATALOG.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'{len(allowed)} ingredients ({len(new_ids)} new), '
          f'{len(products)} products')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
