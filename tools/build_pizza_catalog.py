"""Generate the pizza definition and seed data from PIZZA_CATALOG.md.

Usage (from repo root): python tools/build_pizza_catalog.py
Outputs: definitions/pizza.json, definitions/pizza.temp.json,
         tools/seed/pizza_ingredients.json, tools/seed/pizza_products.json
Every price and owner decision here is TEMP until OWNER_INPUTS.md is filled.
"""
import glob
import json
import os
import re
from pathlib import Path

# key, Arabic name (PIZZA_CATALOG.md section 2)
INGREDIENTS = [
    ('mozzarella', 'موزاريلا'), ('olive_black', 'زيتون أسود'),
    ('mushroom', 'مشروم'), ('bell_pepper_green', 'فلفل أخضر'),
    ('ham', 'هام'), ('chicken', 'فراخ'), ('onion', 'بصل'),
    ('pepperoni', 'بيبروني'), ('sausage', 'سوسيس'), ('tomato', 'طماطم'),
    ('corn', 'ذرة'), ('basil', 'ريحان'), ('oregano', 'أوريجانو'),
    ('cheddar', 'شيدر'), ('feta', 'فيتا'), ('parmesan', 'بارميزان'),
    ('bacon', 'بيكون'), ('ground_beef', 'لحمة مفرومة'),
    ('bell_pepper_red', 'فلفل أحمر'), ('red_onion', 'بصل أحمر'),
    ('cherry_tomato', 'طماطم كرزية'), ('garlic', 'ثوم'),
    ('parsley', 'بقدونس'), ('roumi', 'رومي'), ('tuna', 'تونة'),
    ('olive_green', 'زيتون أخضر'), ('pineapple', 'أناناس'),
    ('jalapeno', 'هالبينو'), ('artichoke', 'خرشوف'),
    ('blue_cheese', 'جبنة زرقاء'), ('salami_spicy', 'سلامي حار'),
    ('basterma', 'بسطرمة'), ('mortadella', 'مرتديلا'), ('shrimp', 'جمبري'),
    ('calamari', 'حلقات حبار'), ('anchovy', 'أنشوجة'),
    ('chili_red', 'فلفل حار أحمر'), ('capers', 'كبر'),
]

# Sauces (owner request: poured as a liquid and spread evenly, and the
# sauces every restaurant offers as extras): id, Arabic, English, extra EGP,
# colour the canvas pours (ARGB). Egyptian-market prices set by the
# developer at the owner's request. Icons: tools/process_sauce_assets.py.
SAUCES = [
    ('ketchup', 'كاتشب', 'Ketchup', 5, 0xFFB01E1A),
    ('mayonnaise', 'مايونيز', 'Mayonnaise', 5, 0xFFF3EAC4),
    ('garlic_sauce', 'ثومية', 'Garlic sauce', 10, 0xFFFAF6E8),
    ('bbq_sauce', 'صوص باربكيو', 'BBQ sauce', 10, 0xFF6E2C17),
    ('ranch_sauce', 'صوص رانش', 'Ranch sauce', 15, 0xFFEFEDE0),
    ('hot_sauce', 'صوص حار', 'Hot sauce', 10, 0xFFD8401C),
    ('honey_mustard', 'هني ماستر', 'Honey mustard', 15, 0xFFD9A030),
    ('cheddar_sauce', 'صوص شيدر', 'Cheddar sauce', 15, 0xFFF0A21C),
    ('pesto_sauce', 'صوص بيستو', 'Pesto sauce', 20, 0xFF4F7A2C),
]
SAUCE_IDS = [k for k, *_ in SAUCES]
# Each sauce is poured at its own angle (degrees, 0-180: params are never
# negative), so two sauces cross.
SAUCE_ANGLES = [35, 145, 70, 110, 0, 90, 20, 125, 55]
# How the sauces are poured on the pizza: passes per unit, line width, wave
# (of the base radius), up to near the crust.
SAUCE_POUR = {'lines': 7, 'lineWidth': 0.04, 'wave': 0.006, 'radius': 0.8}
# A recipe with a sauce other than tomato (PRODUCTS below) shows it poured
# on top, as a default the customer can take off.
PRODUCT_SAUCE = {'bbq': 'bbq_sauce', 'ranch': 'ranch_sauce',
                 'hot': 'hot_sauce', 'pesto': 'pesto_sauce'}
# Cheeses drawn in code (owner request: grated, spread evenly, not piles):
# their pieces are ing_<id>_gNN.webp (tools/process_cheese_assets.py); the
# photo ing_<id>_01.webp is kept only as the colour reference. Each piece
# is a generous sprinkle (owner: a lot of cheese, not a little), scattered
# with a minimum gap (even, without the rings' circles) out to near the
# crust: id -> minimum gap between pieces.
CHEESE_GAP = {'mozzarella': 0.2, 'cheddar': 0.22, 'roumi': 0.23,
              'parmesan': 0.25, 'feta': 0.27, 'blue_cheese': 0.29}
DRAWN_CHEESES = list(CHEESE_GAP)

# id, Arabic name, sauce, default ingredients (PIZZA_CATALOG.md section 1).
# Quattro Stagioni is excluded: it needs a quartered base (half-and-half).
PRODUCTS = [
    ('margherita', 'مارجريتا', 'tomato', ['mozzarella', 'basil']),
    ('marinara', 'مارينارا', 'tomato', ['garlic', 'oregano']),
    ('cheese', 'جبنة', 'tomato', ['mozzarella']),
    ('pepperoni', 'بيبروني', 'tomato', ['mozzarella', 'pepperoni']),
    ('quattro_formaggi', 'أربعة أجبان', 'tomato',
     ['mozzarella', 'blue_cheese', 'parmesan', 'cheddar']),
    ('egyptian_mixed_cheese', 'مشكل جبن', 'tomato',
     ['mozzarella', 'cheddar', 'roumi', 'feta']),
    ('capricciosa', 'كابريتشوزا', 'tomato',
     ['mozzarella', 'ham', 'mushroom', 'artichoke', 'olive_black']),
    ('diavola', 'ديافولا', 'tomato', ['mozzarella', 'salami_spicy', 'chili_red']),
    ('ham_mushroom', 'هام ومشروم', 'tomato', ['mozzarella', 'ham', 'mushroom']),
    ('napoletana', 'نابوليتانا', 'tomato',
     ['mozzarella', 'anchovy', 'capers', 'olive_black', 'oregano']),
    ('veggie', 'خضار', 'tomato',
     ['mozzarella', 'bell_pepper_green', 'bell_pepper_red', 'mushroom',
      'onion', 'tomato', 'olive_black', 'corn']),
    ('hawaiian', 'هاواي', 'tomato', ['mozzarella', 'ham', 'pineapple']),
    ('bbq_chicken', 'فراخ باربكيو', 'bbq', ['mozzarella', 'chicken', 'red_onion']),
    ('chicken_ranch', 'فراخ رانش', 'ranch',
     ['mozzarella', 'chicken', 'bacon', 'cherry_tomato']),
    ('chicken', 'فراخ', 'tomato',
     ['mozzarella', 'chicken', 'bell_pepper_green', 'mushroom', 'olive_black']),
    ('chicken_fajita', 'فراخ فاهيتا', 'tomato',
     ['mozzarella', 'chicken', 'bell_pepper_green', 'bell_pepper_red', 'onion']),
    ('supreme', 'سوبريم', 'tomato',
     ['mozzarella', 'pepperoni', 'sausage', 'bell_pepper_green', 'onion',
      'mushroom', 'olive_black']),
    ('meat_lovers', 'ميت لافرز', 'tomato',
     ['mozzarella', 'pepperoni', 'sausage', 'ham', 'bacon', 'ground_beef']),
    ('sausage', 'سوسيس', 'tomato', ['mozzarella', 'sausage']),
    ('mushroom', 'مشروم', 'tomato', ['mozzarella', 'mushroom', 'parsley']),
    ('tuna', 'تونة', 'tomato',
     ['mozzarella', 'tuna', 'onion', 'olive_black', 'corn']),
    ('seafood', 'مأكولات بحرية', 'tomato',
     ['mozzarella', 'shrimp', 'calamari', 'garlic', 'parsley']),
    ('mexican', 'مكسيكانا', 'hot',
     ['mozzarella', 'ground_beef', 'jalapeno', 'onion', 'bell_pepper_green',
      'corn']),
    ('greek', 'يوناني', 'tomato',
     ['mozzarella', 'feta', 'olive_black', 'tomato', 'red_onion', 'oregano']),
    ('pesto_chicken', 'فراخ بيستو', 'pesto',
     ['mozzarella', 'chicken', 'cherry_tomato', 'parmesan']),
    ('basterma', 'بسطرمة', 'tomato',
     ['mozzarella', 'basterma', 'bell_pepper_green', 'tomato']),
    ('mortadella', 'مرتديلا', 'tomato', ['mozzarella', 'mortadella', 'olive_green']),
]

# Motion per ingredient: (enter, exit, pieces per unit). ANIMATIONS.md 4.
# Proposed values, calibrated against the approved reference (AC-11/12).
MOTION = {
    'mozzarella': ('shower', 'dissolve', 30), 'cheddar': ('shower', 'dissolve', 24),
    'roumi': ('shower', 'dissolve', 22), 'feta': ('sprinkle', 'dissolve', 16),
    'blue_cheese': ('sprinkle', 'dissolve', 14), 'parmesan': ('sprinkle', 'dissolve', 18),
    'pepperoni': ('drop', 'liftFade', 10), 'salami_spicy': ('drop', 'liftFade', 10),
    'ham': ('drop', 'liftFade', 9), 'sausage': ('drop', 'liftFade', 9),
    'bacon': ('drop', 'liftFade', 10), 'ground_beef': ('shower', 'dissolve', 24),
    'chicken': ('toss', 'liftFade', 12), 'basterma': ('drop', 'liftFade', 9),
    'mortadella': ('drop', 'liftFade', 9), 'tuna': ('shower', 'dissolve', 14),
    'shrimp': ('toss', 'liftFade', 6), 'calamari': ('toss', 'liftFade', 10),
    'anchovy': ('toss', 'liftFade', 8), 'bell_pepper_green': ('drop', 'liftFade', 10),
    'bell_pepper_red': ('drop', 'liftFade', 10), 'mushroom': ('drop', 'liftFade', 12),
    'onion': ('drop', 'liftFade', 14), 'red_onion': ('drop', 'liftFade', 14),
    'tomato': ('drop', 'liftFade', 8), 'cherry_tomato': ('drop', 'liftFade', 10),
    'olive_black': ('drop', 'liftFade', 14), 'olive_green': ('drop', 'liftFade', 14),
    'corn': ('sprinkle', 'dissolve', 30), 'pineapple': ('drop', 'liftFade', 10),
    'jalapeno': ('drop', 'liftFade', 14), 'chili_red': ('drop', 'liftFade', 12),
    'artichoke': ('toss', 'liftFade', 8), 'capers': ('sprinkle', 'dissolve', 14),
    'garlic': ('drop', 'liftFade', 14), 'basil': ('float', 'liftFade', 8),
    'oregano': ('sprinkle', 'dissolve', 18), 'parsley': ('sprinkle', 'dissolve', 18),
}

# Smaller pieces for dense scatter (crumbs, kernels, herbs, grated cheese:
# a few shreds or crumbles per piece, many pieces).
PIECE_SIZE = {
    'mozzarella': 0.2, 'cheddar': 0.19, 'roumi': 0.18, 'ground_beef': 0.09,
    'corn': 0.08, 'oregano': 0.09, 'parsley': 0.09, 'parmesan': 0.18,
    'capers': 0.09, 'feta': 0.17, 'blue_cheese': 0.17,
}

# Menu groups (owner request), in display order, and each product's group.
PRODUCT_GROUPS = [
    ('chicken', 'بيتزا فراخ'), ('meat', 'بيتزا لحوم'),
    ('cheese', 'عشاق الجبن'), ('veggie', 'خضار'), ('seafood', 'سي فود'),
]
PRODUCT_GROUP = {
    'chicken': 'chicken', 'bbq_chicken': 'chicken', 'chicken_ranch': 'chicken',
    'chicken_fajita': 'chicken', 'pesto_chicken': 'chicken',
    'pepperoni': 'meat', 'diavola': 'meat', 'ham_mushroom': 'meat',
    'capricciosa': 'meat', 'hawaiian': 'meat', 'supreme': 'meat',
    'meat_lovers': 'meat', 'sausage': 'meat', 'mexican': 'meat',
    'basterma': 'meat', 'mortadella': 'meat',
    'margherita': 'cheese', 'cheese': 'cheese', 'quattro_formaggi': 'cheese',
    'egyptian_mixed_cheese': 'cheese',
    'marinara': 'veggie', 'veggie': 'veggie', 'mushroom': 'veggie', 'greek': 'veggie',
    'tuna': 'seafood', 'seafood': 'seafood', 'napoletana': 'seafood',
}

# English display names (owner decision: bilingual, English default).
INGREDIENT_EN = {
    'mozzarella': 'Mozzarella', 'olive_black': 'Black olives', 'mushroom': 'Mushrooms',
    'bell_pepper_green': 'Green pepper', 'ham': 'Ham', 'chicken': 'Chicken',
    'onion': 'Onion', 'pepperoni': 'Pepperoni', 'sausage': 'Sausage',
    'tomato': 'Tomato', 'corn': 'Sweet corn', 'basil': 'Basil', 'oregano': 'Oregano',
    'cheddar': 'Cheddar', 'feta': 'Feta', 'parmesan': 'Parmesan', 'bacon': 'Bacon',
    'ground_beef': 'Ground beef', 'bell_pepper_red': 'Red pepper',
    'red_onion': 'Red onion', 'cherry_tomato': 'Cherry tomatoes', 'garlic': 'Garlic',
    'parsley': 'Parsley', 'roumi': 'Roumi cheese', 'tuna': 'Tuna',
    'olive_green': 'Green olives', 'pineapple': 'Pineapple', 'jalapeno': 'Jalapeño',
    'artichoke': 'Artichoke', 'blue_cheese': 'Blue cheese',
    'salami_spicy': 'Spicy salami', 'basterma': 'Basterma', 'mortadella': 'Mortadella',
    'shrimp': 'Shrimp', 'calamari': 'Calamari', 'anchovy': 'Anchovies',
    'chili_red': 'Red chili', 'capers': 'Capers',
}
PRODUCT_EN = {
    'margherita': 'Margherita', 'marinara': 'Marinara', 'cheese': 'Cheese',
    'pepperoni': 'Pepperoni', 'quattro_formaggi': 'Quattro Formaggi',
    'egyptian_mixed_cheese': 'Mixed Cheese', 'capricciosa': 'Capricciosa',
    'diavola': 'Diavola', 'ham_mushroom': 'Ham & Mushroom', 'napoletana': 'Napoletana',
    'veggie': 'Veggie', 'hawaiian': 'Hawaiian', 'bbq_chicken': 'BBQ Chicken',
    'chicken_ranch': 'Chicken Ranch', 'chicken': 'Chicken',
    'chicken_fajita': 'Chicken Fajita', 'supreme': 'Supreme',
    'meat_lovers': 'Meat Lovers', 'sausage': 'Sausage', 'mushroom': 'Mushroom',
    'tuna': 'Tuna', 'seafood': 'Seafood', 'mexican': 'Mexicana', 'greek': 'Greek',
    'pesto_chicken': 'Pesto Chicken', 'basterma': 'Basterma',
    'mortadella': 'Mortadella',
}
GROUP_EN = {'chicken': 'Chicken pizza', 'meat': 'Meat pizza',
            'cheese': 'Cheese lovers', 'veggie': 'Veggie', 'seafood': 'Seafood'}

# Trial subset used for development/testing (seeded first in P1-A03).
TRIAL_PRODUCT_IDS = ['margherita', 'pepperoni', 'veggie', 'chicken', 'supreme']

TEMP_NOTE = ('TEMP: placeholder values for development only. Replace from '
             'OWNER_INPUTS.md before gate A. Must never be seeded to production.')
# Prices: Egyptian-market estimates (Banha, mid-range, 2026) set by the
# developer at the owner's request ("make the prices based on the Egyptian
# market"). Amounts in EGP; stored as piasters. basePrice is the small size.
EGP = 100

# Size tiers: (small, medium, large) in EGP.
PRICE_TIERS = {
    'basic':   (130, 180, 230),
    'veggie':  (145, 195, 250),
    'classic': (160, 215, 270),
    'cheese':  (165, 225, 285),
    'loaded':  (175, 235, 295),
    'seafood': (210, 280, 350),
}
PRODUCT_TIER = {
    'margherita': 'basic', 'marinara': 'basic', 'cheese': 'basic',
    'veggie': 'veggie', 'mushroom': 'veggie', 'greek': 'veggie',
    'pepperoni': 'classic', 'ham_mushroom': 'classic', 'hawaiian': 'classic',
    'sausage': 'classic', 'mortadella': 'classic', 'chicken': 'classic',
    'tuna': 'classic',
    'quattro_formaggi': 'cheese', 'egyptian_mixed_cheese': 'cheese',
    'capricciosa': 'loaded', 'diavola': 'loaded', 'bbq_chicken': 'loaded',
    'chicken_ranch': 'loaded', 'chicken_fajita': 'loaded', 'supreme': 'loaded',
    'meat_lovers': 'loaded', 'mexican': 'loaded', 'pesto_chicken': 'loaded',
    'basterma': 'loaded', 'napoletana': 'loaded',
    'seafood': 'seafood',
}

# Option groups: (id, ar, en, [(choiceId, ar, en, extraEGP, baseAssetId)]).
# Choice ids are unique across groups (product optionDeltas are keyed by
# choice id). Dough type was removed at the owner's request; stuffed crust
# has its own base (tools/process_stuffed_crust.py), so the
# rim visibly thickens when chosen (owner request).
OPTION_GROUPS = [
    ('crust', 'الحواف', 'Crust', 'classic_crust', [
        ('classic_crust', 'عادية', 'Classic', 0, None),
        ('stuffed_crust', 'ستافت كراست', 'Stuffed crust', 45,
         'base_pizza_stuffed_raw'),
    ]),
]

# Extra topping price per unit in EGP (same for every size, owner P0-05).
EXTRA_PRICE = {
    'basil': 5, 'oregano': 5, 'parsley': 5, 'garlic': 5, 'chili_red': 5,
    'onion': 10, 'red_onion': 10, 'tomato': 10, 'corn': 10,
    'bell_pepper_green': 10, 'bell_pepper_red': 10,
    'olive_black': 12, 'olive_green': 12, 'cherry_tomato': 12, 'jalapeno': 12,
    'mushroom': 15, 'pineapple': 15, 'capers': 15,
    'artichoke': 25, 'feta': 20,
    'mozzarella': 30, 'cheddar': 25, 'roumi': 25, 'parmesan': 30,
    'blue_cheese': 35,
    'mortadella': 25, 'ham': 30, 'sausage': 30, 'pepperoni': 35,
    'salami_spicy': 35, 'chicken': 35, 'ground_beef': 35, 'tuna': 35,
    'bacon': 40, 'anchovy': 40, 'basterma': 45,
    'calamari': 50, 'shrimp': 60,
}


def asset_files(files, key: str) -> list:
    """An ingredient's image files: its photo variants (ing_<id>_NN), its
    drawn cheese pieces (ing_<id>_gNN) or its sauce icon (ing_<id>_cup).
    Matched exactly, so ids that share a start (cheddar, cheddar_sauce) never
    take each other's files."""
    kind = ('cup' if key in SAUCE_IDS else r'g\d+' if key in DRAWN_CHEESES
            else r'\d+')
    return [f for f in files
            if re.fullmatch(rf'ing_{re.escape(key)}_{kind}\.webp', f)]



def sauce_params(sauces, angles, pour) -> dict:
    """Placement params of poured sauces: colour, angle and pour each."""
    params = {}
    for i, (k, *_, colour) in enumerate(sauces):
        params[f'color:{k}'] = colour
        params[f'angle:{k}'] = angles[i % len(angles)]
        for p, v in pour.items():
            params[f'{p}:{k}'] = v
    return params


def dump(path: str, data) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main() -> None:
    keys = {k for k, _ in INGREDIENTS}
    assert set(MOTION) == keys, set(MOTION) ^ keys
    assert set(PRODUCT_GROUP) == {p[0] for p in PRODUCTS}
    assert set(PRODUCT_TIER) == {p[0] for p in PRODUCTS}
    assert set(EXTRA_PRICE) == keys, set(EXTRA_PRICE) ^ keys
    for pid, _, sauce, defaults in PRODUCTS:
        unknown = set(defaults) - keys
        assert not unknown, f'{pid}: unknown ingredients {unknown}'
        assert sauce == 'tomato' or sauce in PRODUCT_SAUCE, (pid, sauce)
    assert not keys & set(SAUCE_IDS)
    files = sorted(os.path.basename(f)
                   for f in glob.glob('assets_src/pizza/ingredients/*.webp'))

    dump('definitions/pizza.json', {
        'id': 'pizza',
        'definitionVersion': 1,
        'name': 'بيتزا',
        'names': {'en': 'Pizza', 'ar': 'بيتزا'},
        'base': {'shape': 'circle', 'rawAssetId': 'base_pizza_regular_raw'},
        'allowedIngredientIds': [k for k, _ in INGREDIENTS] + SAUCE_IDS,
        # TEMP: calibrated during the P1-B00 drawing prototype.
        'placement': {'strategy': 'rings', 'params': {
            'pieceSize': 0.13, 'piecesPerUnit': 9, 'radius': 0.74, 'minGap': 0.16,
            **{f'piecesPerUnit:{k}': v[2] for k, v in MOTION.items()},
            **{f'pieceSize:{k}': v for k, v in PIECE_SIZE.items()},
            # The small cheese pieces spread out to near the crust.
            **{f'radius:{k}': 0.72 for k in DRAWN_CHEESES},
            **{f'minGap:{k}': v for k, v in CHEESE_GAP.items()},
            **sauce_params(SAUCES, SAUCE_ANGLES, SAUCE_POUR)},
            'byIngredient': {**{k: 'scatter' for k in DRAWN_CHEESES},
                             **{k: 'sauce' for k in SAUCE_IDS}}},
        # Sauces are poured over everything else.
        'layerOverrides': {k: 40 for k in SAUCE_IDS},
        'constraints': {'maxQty': 2},
        'sizes': [
            {'id': 's', 'name': 'صغير', 'names': {'en': 'Small', 'ar': 'صغير'}, 'scale': 0.82},
            {'id': 'm', 'name': 'وسط', 'names': {'en': 'Medium', 'ar': 'وسط'}, 'scale': 0.91},
            {'id': 'l', 'name': 'كبير', 'names': {'en': 'Large', 'ar': 'كبير'}, 'scale': 1.0},
        ],
        'optionGroups': [{
            'id': gid, 'name': gar, 'names': {'en': gen, 'ar': gar},
            'defaultChoiceId': default,
            'choices': [{
                'id': c, 'name': ar, 'names': {'en': en, 'ar': ar},
                **({'base': {'shape': 'circle', 'rawAssetId': base}}
                   if base else {}),
            } for c, ar, en, _, base in choices],
        } for gid, gar, gen, default, choices in OPTION_GROUPS],
        # ANIMATIONS.md 7 + OVEN.md 4 (proposed values, TEMP until G06).
        'animation': [
            # Durations requested by the owner (longer oven); weights match.
            {'step': 'Oven', 'weight': 2200, 'params': {
                'durationMs': 2200, 'saturation': 1.45,
                'images': {
                    'hearth': 'oven_hearth', 'fireBack': 'oven_fire_back',
                    'fireFront': 'oven_fire_front', 'embers': 'oven_embers',
                    'steam': 'oven_steam', 'rim': 'oven_rim',
                },
                'scrimMaxPct': 35, 'vignetteMaxPct': 45, 'shrinkTo': 0.9,
                'flashPeakPct': 35,
            }},
            {'step': 'Swap', 'weight': 300, 'params': {'durationMs': 300}},
            {'step': 'FlyToCart', 'weight': 900, 'params': {
                'durationMs': 900,
                'shrinkTo': 0.18, 'arcControlPct': 20, 'rotateDeg': -12,
            }},
        ],
        'productGroups': [{'id': g, 'name': n, 'names': {'en': GROUP_EN[g], 'ar': n}}
                          for g, n in PRODUCT_GROUPS],
        # Every pizza offers the sauces as extras, in a section of their own.
        'addOnGroups': [{'id': 'sauces', 'name': 'الصوصات',
                         'names': {'en': 'Sauces', 'ar': 'الصوصات'},
                         'ingredientIds': SAUCE_IDS}],
        'ingredientMotion': {
            k: {'enter': v[0], 'exit': v[1]} for k, v in MOTION.items()
        },
        'assetSpecs': {
            'base': {'formats': ['png', 'webp'], 'maxBytes': 500 * 1024,
                     'transparent': True},
            'ingredient': {'formats': ['png', 'webp'], 'maxBytes': 150 * 1024,
                           'transparent': True},
            # Product photos the admin uploads for the menu (P3-04).
            'final': {'formats': ['png', 'webp'], 'maxBytes': 500 * 1024,
                      'transparent': True},
        },
    })
    # Sidecar: the definition schema stays strict, TEMP status lives here.
    dump('definitions/pizza.temp.json', {
        '_note': TEMP_NOTE,
        'tempFields': ['placement.params', 'ingredientMotion'],
        'pendingNotes': [
            'Stuffed crust base is derived from the regular base '
            '(tools/process_stuffed_crust.py) until a photographed one exists.',
            'No cooked base asset yet (base.cookedAssetId).',
        ],
    })

    ingredients = []
    entries = ([(k, name, INGREDIENT_EN[k], EXTRA_PRICE[k]) for k, name in INGREDIENTS]
               + [(k, ar, en, extra) for k, ar, en, extra, _ in SAUCES])
    for k, name, en, extra in entries:
        variants = asset_files(files, k)
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': name, 'names': {'en': en, 'ar': name},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': extra * EGP, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/pizza_ingredients.json', {
        '_note': 'Extra prices: Egyptian-market estimates approved by the '
                 'owner (EXTRA_PRICE in tools/build_pizza_catalog.py).',
        'ingredients': ingredients,
    })

    products = [{
        'id': f'pizza_{pid}', 'categoryId': 'pizza', 'name': name,
        'names': {'en': PRODUCT_EN[pid], 'ar': name},
        'description': '',
        'basePrice': PRICE_TIERS[PRODUCT_TIER[pid]][0] * EGP,
        'imageAssetId': f'final_pizza_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults + ([PRODUCT_SAUCE[sauce]]
                                          if sauce in PRODUCT_SAUCE else [])],
        'isAvailable': True,
        'sizeDeltas': {
            size: (PRICE_TIERS[PRODUCT_TIER[pid]][t] -
                   PRICE_TIERS[PRODUCT_TIER[pid]][0]) * EGP
            for t, size in enumerate(('s', 'm', 'l'))
        },
        'optionDeltas': {c: extra * EGP for *_, choices in OPTION_GROUPS
                         for c, _, _, extra, _ in choices},
        'displayOrder': i,
        'groupId': PRODUCT_GROUP[pid],
        'sauce': sauce,
    } for i, (pid, name, sauce, defaults) in enumerate(PRODUCTS)]
    dump('tools/seed/pizza_products.json', {
        'temp': True, '_note': TEMP_NOTE,
        'tempFields': ['defaults[].removable'],
        'excluded': {'quattro_stagioni': 'Needs a quartered base (half-and-half,'
                     ' CLAUDE.md section 10 Q3). Not supported in phase 1.'},
        'pendingNotes': [
            'Non-tomato sauces (bbq, ranch, hot, pesto) are poured on top as '
            'a removable default; the base still shows tomato.',
            'Final product images (final_pizza_*) not delivered yet.',
        ],
        'products': products,
    })
    trial = [p for p in products
             if p['id'].removeprefix('pizza_') in TRIAL_PRODUCT_IDS]
    assert len(trial) == len(TRIAL_PRODUCT_IDS)
    dump('tools/seed/pizza_trial.json', {
        'temp': True, '_note': TEMP_NOTE,
        'tempFields': ['defaults[].removable'],
        'products': trial,
    })
    print(f'{len(ingredients)} ingredients, {len(products)} products, '
          f'{len(trial)} trial')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
