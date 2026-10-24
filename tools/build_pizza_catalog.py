"""Generate the pizza definition and seed data from PIZZA_CATALOG.md.

Usage (from repo root): python tools/build_pizza_catalog.py
Outputs: definitions/pizza.json, definitions/pizza.temp.json,
         tools/seed/pizza_ingredients.json, tools/seed/pizza_products.json
Every price and owner decision here is TEMP until OWNER_INPUTS.md is filled.
"""
import glob
import json
import os
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
    'mozzarella': ('shower', 'dissolve', 14), 'cheddar': ('shower', 'dissolve', 14),
    'roumi': ('shower', 'dissolve', 14), 'feta': ('shower', 'dissolve', 12),
    'blue_cheese': ('shower', 'dissolve', 10), 'parmesan': ('sprinkle', 'dissolve', 20),
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

# Smaller pieces for dense scatter (crumbs, kernels, herbs); spread cheeses
# stay larger so they read as a covering layer.
PIECE_SIZE = {
    'mozzarella': 0.2, 'cheddar': 0.2, 'roumi': 0.12, 'ground_beef': 0.09,
    'corn': 0.08, 'oregano': 0.09, 'parsley': 0.09, 'parmesan': 0.1,
    'capers': 0.09,
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
TEMP_EXTRA_PRICE = 1500   # TEMP piasters
TEMP_BASE_PRICE = 10000   # TEMP piasters


def dump(path: str, data) -> None:
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


def main() -> None:
    keys = {k for k, _ in INGREDIENTS}
    assert set(MOTION) == keys, set(MOTION) ^ keys
    assert set(PRODUCT_GROUP) == {p[0] for p in PRODUCTS}
    for pid, _, _, defaults in PRODUCTS:
        unknown = set(defaults) - keys
        assert not unknown, f'{pid}: unknown ingredients {unknown}'
    files = sorted(os.path.basename(f)
                   for f in glob.glob('assets_src/pizza/ingredients/*.webp'))

    dump('definitions/pizza.json', {
        'id': 'pizza',
        'definitionVersion': 1,
        'name': 'بيتزا',
        'names': {'en': 'Pizza', 'ar': 'بيتزا'},
        'base': {'shape': 'circle', 'rawAssetId': 'base_pizza_regular_raw'},
        'allowedIngredientIds': [k for k, _ in INGREDIENTS],
        # TEMP: calibrated during the P1-B00 drawing prototype.
        'placement': {'strategy': 'rings', 'params': {
            'pieceSize': 0.13, 'piecesPerUnit': 9, 'radius': 0.74, 'minGap': 0.16,
            **{f'piecesPerUnit:{k}': v[2] for k, v in MOTION.items()},
            **{f'pieceSize:{k}': v for k, v in PIECE_SIZE.items()},
            # Spread cheeses pack tighter to cover the base.
            **{f'{p}:{ing}': v for ing in ('mozzarella', 'cheddar')
               for p, v in (('minGap', 0.12), ('radius', 0.72))}}},
        'constraints': {'maxQty': 2},
        'sizes': [
            {'id': 's', 'name': 'صغير', 'names': {'en': 'Small', 'ar': 'صغير'}, 'scale': 0.82},
            {'id': 'm', 'name': 'وسط', 'names': {'en': 'Medium', 'ar': 'وسط'}, 'scale': 0.91},
            {'id': 'l', 'name': 'كبير', 'names': {'en': 'Large', 'ar': 'كبير'}, 'scale': 1.0},
        ],
        'optionGroups': [{
            'id': 'dough', 'name': 'العجينة', 'names': {'en': 'Dough', 'ar': 'العجينة'},
            'defaultChoiceId': 'regular',
            'choices': [{'id': 'regular', 'name': 'عادية',
                         'names': {'en': 'Regular', 'ar': 'عادية'}}],
        }],
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
        'ingredientMotion': {
            k: {'enter': v[0], 'exit': v[1]} for k, v in MOTION.items()
        },
        'assetSpecs': {
            'base': {'formats': ['png', 'webp'], 'maxBytes': 500 * 1024,
                     'transparent': True},
            'ingredient': {'formats': ['png', 'webp'], 'maxBytes': 150 * 1024,
                           'transparent': True},
        },
    })
    # Sidecar: the definition schema stays strict, TEMP status lives here.
    dump('definitions/pizza.temp.json', {
        '_note': TEMP_NOTE,
        'tempFields': ['constraints.maxQty', 'sizes', 'optionGroups',
                       'placement.params', 'ingredientMotion', 'animation'],
        'pendingNotes': [
            'Only the regular dough exists (no other dough assets yet).',
            'No cooked base asset yet (base.cookedAssetId).',
        ],
    })

    ingredients = []
    for k, name in INGREDIENTS:
        variants = [f for f in files if f.startswith(f'ing_{k}_')]
        assert variants, f'no asset files for {k}'
        ingredients.append({
            'id': k, 'name': name, 'names': {'en': INGREDIENT_EN[k], 'ar': name},
            'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': TEMP_EXTRA_PRICE, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/pizza_ingredients.json', {
        'temp': True, '_note': TEMP_NOTE, 'tempFields': ['extraPrice'],
        'ingredients': ingredients,
    })

    products = [{
        'id': f'pizza_{pid}', 'categoryId': 'pizza', 'name': name,
        'names': {'en': PRODUCT_EN[pid], 'ar': name},
        'description': '', 'basePrice': TEMP_BASE_PRICE,
        'imageAssetId': f'final_pizza_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults],
        'isAvailable': True,
        'sizeDeltas': {'s': 0, 'm': 0, 'l': 0},
        'optionDeltas': {'regular': 0},
        'displayOrder': i,
        'groupId': PRODUCT_GROUP[pid],
        'sauce': sauce,
    } for i, (pid, name, sauce, defaults) in enumerate(PRODUCTS)]
    dump('tools/seed/pizza_products.json', {
        'temp': True, '_note': TEMP_NOTE,
        'tempFields': ['basePrice', 'sizeDeltas', 'optionDeltas',
                       'defaults[].removable'],
        'excluded': {'quattro_stagioni': 'Needs a quartered base (half-and-half,'
                     ' CLAUDE.md section 10 Q3). Not supported in phase 1.'},
        'pendingNotes': [
            'Non-tomato sauces (bbq, ranch, hot, pesto) need Drizzle placement '
            '(phase 2); shown on the tomato base until then.',
            'Final product images (final_pizza_*) not delivered yet.',
        ],
        'products': products,
    })
    trial = [p for p in products
             if p['id'].removeprefix('pizza_') in TRIAL_PRODUCT_IDS]
    assert len(trial) == len(TRIAL_PRODUCT_IDS)
    dump('tools/seed/pizza_trial.json', {
        'temp': True, '_note': TEMP_NOTE,
        'tempFields': ['basePrice', 'sizeDeltas', 'optionDeltas',
                       'defaults[].removable'],
        'products': trial,
    })
    print(f'{len(ingredients)} ingredients, {len(products)} products, '
          f'{len(trial)} trial')


if __name__ == '__main__':
    os.chdir(Path(__file__).resolve().parent.parent)
    main()
