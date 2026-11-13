"""Generate the crepe definition, seed data and catalog document.

Prices are Egyptian-market estimates (Banha, 2026) set by the developer at
the owner's request ("start the crepe at market prices"). One size.

Usage (from repo root): python tools/build_crepe_catalog.py
Outputs: definitions/crepe.json, definitions/crepe.temp.json,
         tools/seed/crepe_ingredients.json, tools/seed/crepe_products.json,
         CREPE_CATALOG.md (readable: products, ingredients, extras, prices)

Savoury crepes reuse the pizza ingredients and savoury sauces (one record
and one image per ingredient, defined in tools/seed/pizza_ingredients.json);
only the new sweet ingredients and sauces are defined here (images:
tools/process_crepe_assets.py, tools/process_sauce_assets.py).
"""
import glob
import json
import os
import re
from pathlib import Path

from build_pizza_catalog import (DRAWN_CHEESES, SAUCES as PIZZA_SAUCES,
                                 sauce_params, sprite_fill)

EGP = 100

# New ingredients introduced by the crepe: id, Arabic, English, extra EGP,
# pieces per unit, piece size, enter motion.
NEW_INGREDIENTS = [
    ('lotus', 'لوتس', 'Lotus', 25, 12, 0.16, 'sprinkle'),
    ('banana', 'موز', 'Banana', 10, 14, 0.12, 'toss'),
    ('strawberry', 'فراولة', 'Strawberry', 15, 12, 0.13, 'toss'),
]

# Sweet sauces (owner request: poured as a liquid and spread evenly, and the
# sauces restaurants offer as extras): id, Arabic, English, extra EGP,
# colour the canvas pours (ARGB). Nutella and white chocolate were drawn as
# drops before; now they are poured like every sauce.
SWEET_SAUCES = [
    ('nutella', 'نوتيلا', 'Nutella', 20, 0xFF4A2614),
    ('white_chocolate', 'شوكولاتة بيضاء', 'White chocolate', 20, 0xFFF3E9D2),
    ('chocolate_sauce', 'صوص شوكولاتة', 'Chocolate sauce', 15, 0xFF3A1D10),
    ('caramel_sauce', 'صوص كراميل', 'Caramel sauce', 15, 0xFFB8691E),
    ('lotus_sauce', 'صوص لوتس', 'Lotus sauce', 20, 0xFFA8652E),
    ('strawberry_sauce', 'صوص فراولة', 'Strawberry sauce', 15, 0xFFC21A34),
    ('honey', 'عسل', 'Honey', 15, 0xFFE0A11C),
    ('pistachio_sauce', 'صوص بستاشيو', 'Pistachio sauce', 30, 0xFF97AE55),
]
# The pizza's savoury sauces, offered on savoury crepes (pesto stays a
# pizza sauce).
SAVORY_SAUCES = [x for x in PIZZA_SAUCES if x[0] != 'pesto_sauce']
# Poured across the filling in near-upright passes; two sauces cross.
SAUCE_ANGLES = [62, 118, 90, 76, 104, 50, 130]
SAUCE_POUR = {'lines': 11, 'lineWidth': 0.042, 'wave': 0.005}
SAUCE_IDS = [x[0] for x in SAVORY_SAUCES + SWEET_SAUCES]

# Pieces of a shared ingredient on the crepe, relative to the pizza: the
# filling area is smaller, so fewer pieces keep it about as full.
CREPE_DENSITY = 0.6

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

# Fold lines of the cone, in fractions of the product box: each folds the
# part on its outer side (left, then right) over the filling. They meet in a
# point at the straight edge (owner: an upside-down triangle) and open
# towards the top, where the filling shows.
CONE = [[0.50, 0.75, 0.13, 0.26], [0.87, 0.26, 0.50, 0.75]]
# The open top of the cone: the rim is its top edge (ellipse cx, cy, rx, ry,
# as wide as the cone there), filled by the filling area of the half moon
# (contents x0, y0, x1, y1); the outside is crepe all round, so the filling
# shows only inside the rim, like a wrapped crepe.
OPENING = {'ellipse': [0.5, 0.37, 0.285, 0.095],
           # The whole filling area (FILLING below, in box fractions).
           'contents': [0.16, 0.415, 0.84, 0.685],
           # The finished cone (with its paper and the filling heaped above
           # the rim) grows into this frame to fill the space.
           'frame': [0.16, 0.18, 0.86, 0.77],
           # Served in a kraft paper cone, like the owner's reference photo.
           'sleeve': '#9C7650'}

# Shown on the home page after the pizza.
CATEGORY_ORDER = 1

# Where the filling and sauces go on the half moon (owner request: a larger
# area): a strip `bandWidth` high around `offsetY`, inside `radius` (of the
# base radius; the half moon's straight edge is at y = 0.5).
FILLING = {'radius': 0.68, 'bandWidth': 0.27, 'offsetY': 0.1}
# The fillings' layout (owner request: spread evenly, in harmony): every
# filling mixed over the strip, piece centres inside it, and as full on
# every crepe whatever its number of fillings (share of the strip).
FILLING_LAYOUT = {'inset': 0, 'coverage': 0.55}


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
    savory_ids = [x[0] for x in SAVORY_SAUCES]
    sweet_ids = [x[0] for x in SWEET_SAUCES]
    allowed = SHARED + savory_ids + new_ids + sweet_ids
    shared = SHARED + savory_ids
    assert all(s in pizza_ing for s in shared), set(shared) - set(pizza_ing)
    # The contents box of the opening is the filling area.
    f = FILLING
    assert OPENING['contents'] == [
        round((1 - f['radius']) / 2, 3), round((1 + f['offsetY'] - f['bandWidth']) / 2, 3),
        round((1 + f['radius']) / 2, 3), round((1 + f['offsetY'] + f['bandWidth']) / 2, 3)]
    for pid, *_, defaults in PRODUCTS:
        assert set(defaults) <= set(allowed), (pid, set(defaults) - set(allowed))
    files = sorted(os.path.basename(f) for f in
                   glob.glob('assets_src/crepe/ingredients/*.webp'))

    pp = pizza_def['placement']['params']
    # Fillings lie in a band across the middle (where the crepe is folded
    # over them), sauces are poured over them (P2-04, owner request).
    # The crepe is a half moon (owner request): curved side up, straight
    # edge at 3/4 of the height. The filling covers most of it (FILLING).
    params = {'pieceSize': 0.12, 'piecesPerUnit': 12, **FILLING,
              **FILLING_LAYOUT, 'minGap': 0.1}
    for k in SHARED:
        if f'piecesPerUnit:{k}' in pp:
            params[f'piecesPerUnit:{k}'] = max(
                3, round(pp[f'piecesPerUnit:{k}'] * CREPE_DENSITY))
        for key in ('pieceSize', 'fill'):
            if f'{key}:{k}' in pp:
                params[f'{key}:{k}'] = pp[f'{key}:{k}']
    for k, _, _, _, per, size, _ in NEW_INGREDIENTS:
        params[f'piecesPerUnit:{k}'] = per
        params[f'pieceSize:{k}'] = size
        params[f'fill:{k}'] = sprite_fill(
            f'assets_src/crepe/ingredients/{f}' for f in files
            if re.fullmatch(rf'ing_{re.escape(k)}_\d+\.webp', f))
    cheeses = [k for k in SHARED if k in DRAWN_CHEESES]
    params.update(sauce_params(SAVORY_SAUCES, SAUCE_ANGLES, SAUCE_POUR))
    params.update(sauce_params(SWEET_SAUCES, SAUCE_ANGLES, SAUCE_POUR))
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
        # Owner request: the fillings spread together evenly over the strip
        # (`even`); the grated cheese is a layer of its own under them, and
        # the sauces are poured over the filling.
        'placement': {'strategy': 'even', 'params': params,
                      'byIngredient': {**{k: 'band' for k in cheeses},
                                       **{k: 'sauce' for k in SAUCE_IDS}}},
        'layerOverrides': {**{k: 10 for k in cheeses},
                           **{k: 40 for k in SAUCE_IDS}},
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
                'durationMs': 650, 'stage': 1, 'lines': CONE, 'opening': OPENING,
                'images': {'surface': 'griddle_surface',
                           'back': 'crepe_back'}}},
            {'step': 'Fold', 'weight': 650, 'params': {
                'durationMs': 650, 'stage': 2, 'lines': CONE, 'opening': OPENING,
                'images': {'surface': 'griddle_surface',
                           'back': 'crepe_back'}}},
            {'step': 'Swap', 'weight': 300, 'params': {
                'durationMs': 300, 'folds': 2, 'lines': CONE, 'opening': OPENING,
                'images': {'back': 'crepe_back'}}},
            # Served (in its paper): the griddle and the dim Swap cleared
            # stay away.
            {'step': 'Shrink', 'weight': 350, 'params': {
                'durationMs': 350, 'folds': 2, 'lines': CONE, 'opening': OPENING,
                'shrinkTo': 0.85, 'scrimMaxPct': 0,
                'images': {'back': 'crepe_back'}}},
            {'step': 'FlyToCart', 'weight': 800, 'params': {
                'durationMs': 800, 'folds': 2, 'lines': CONE, 'opening': OPENING,
                'shrinkTo': 0.2, 'arcControlPct': 20, 'rotateDeg': -12,
                'images': {'back': 'crepe_back'}}},
        ],
        'productGroups': [{'id': g, 'name': ar, 'names': {'en': en, 'ar': ar}}
                          for g, ar, en in GROUPS],
        # Savoury crepes offer the savoury sauces, sweet ones the sweet.
        'addOnGroups': [
            {'id': f'{g}_sauces', 'name': 'الصوصات',
             'names': {'en': 'Sauces', 'ar': 'الصوصات'},
             'ingredientIds': ids, 'productGroupIds': [g]}
            for g, ids in (('savory', savory_ids), ('sweet', sweet_ids))],
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
    for k, ar, en, extra, *_ in NEW_INGREDIENTS + SWEET_SAUCES:
        # Pieces: ing_<id>_NN; a sauce: its icon ing_<id>_cup (matched
        # exactly: honey never takes another sauce's file).
        kind = 'cup' if k in sweet_ids else r'\d+'
        variants = [f for f in files
                    if re.fullmatch(rf'ing_{re.escape(k)}_{kind}\.webp', f)]
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': ar, 'names': {'en': en, 'ar': ar},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': extra * EGP, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/crepe_ingredients.json', {
        '_note': 'Ingredients and sauces the crepe introduces. Savoury '
                 'fillings and sauces reuse the pizza records '
                 '(tools/seed/pizza_ingredients.json).',
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
    names = {k: pizza_ing[k]['name'] for k in shared}
    names.update({k: ar for k, ar, *_ in NEW_INGREDIENTS + SWEET_SAUCES})
    extra = {k: pizza_ing[k]['extraPrice'] // EGP for k in shared}
    extra.update({k: e for k, _, _, e, *_ in NEW_INGREDIENTS + SWEET_SAUCES})
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
    for k in SHARED + new_ids:
        src = 'جديد للكريب' if k in new_ids else 'مشترك مع البيتزا'
        img = ('مرسومة بالكود (3 تنويعات)' if k in new_ids
               else 'صور البيتزا الحالية')
        lines.append(f'| `{k}` | {names[k]} | {src} | {img} |')
    lines += ['', '## 3) الصوصات (إضافات)', '',
              '> تُصب سائلة بالتساوي فوق الحشو (بطلب المالك). الحادق يظهر في قسم «الصوصات» للكريب الحادق والحلو للكريب الحلو، وتُضاف حتى 2 فوق الافتراضي. الصوص الحادق مشترك مع البيتزا بنفس السعر.',
              '', '| المعرّف | الاسم | يُعرض مع | السعر |', '| --- | --- | --- | --- |']
    for k in savory_ids + sweet_ids:
        group = 'الكريب الحادق' if k in savory_ids else 'الكريب الحلو'
        lines.append(f'| `{k}` | {names[k]} | {group} | {extra[k]} ج |')
    lines += ['', '## 4) الإضافات وأسعارها', '',
              '> الإضافة تزيد كمية مكوّن موجود في المنتج، بحد أقصى 2 فوق الافتراضي (`maxQty`). سعر المكوّن المشترك هو نفسه في البيتزا والكريب (مصدر واحد).',
              '', '| المكوّن | سعر الإضافة |', '| --- | --- |']
    for k in sorted(SHARED + new_ids, key=lambda x: (extra[x], names[x])):
        lines.append(f'| {names[k]} | {extra[k]} ج |')
    lines += ['', '## 5) ملخص الأسعار', '',
              '| القسم | أقل سعر | أعلى سعر | عدد الأصناف |',
              '| --- | --- | --- | --- |']
    for g, ar, _ in GROUPS:
        ps = [p[4] for p in PRODUCTS if p[3] == g]
        lines.append(f'| {ar} | {min(ps)} ج | {max(ps)} ج | {len(ps)} |')
    lines += ['', '## 6) الصور', '',
              '| الملف | الوصف |', '| --- | --- |',
              '| `assets_src/crepe/bases/base_crepe_raw.webp` | عجينة نيئة |',
              '| `assets_src/crepe/bases/base_crepe_cooked.webp` | كريب مسوّى (بعد الجريل) |',
              '| `assets_src/animation/crepe_back.webp` | ظهر الكريب (الوجه الخارجي بعد الطي، P2-06) |',
              '| `assets_src/animation/griddle_surface.webp` | سطح الجريل (لحركة الجريل P2-05) |',
              '| `assets_src/crepe/ingredients/ing_<id>_0N.webp` | المكونات الحلوة الجديدة، 3 تنويعات لكل مكوّن |',
              '| `assets_src/crepe/ingredients/ing_<id>_cup.webp` | أيقونة كل صوص حلو (الصوص نفسه يُرسم سائلاً بالكود) |',
              '', 'كل الصور مرسومة بالكود (`tools/process_crepe_assets.py`) وتُستبدل بصور حقيقية بنفس الاسم دون تعديل كود.', '']
    Path('CREPE_CATALOG.md').write_text('\n'.join(lines), encoding='utf-8')
    print(f'{len(allowed)} ingredients ({len(new_ids)} new), '
          f'{len(products)} products')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
