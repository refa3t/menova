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
    for pid, _, _, defaults in PRODUCTS:
        unknown = set(defaults) - keys
        assert not unknown, f'{pid}: unknown ingredients {unknown}'
    files = sorted(os.path.basename(f)
                   for f in glob.glob('assets_src/pizza/ingredients/*.webp'))

    dump('definitions/pizza.json', {
        'id': 'pizza',
        'definitionVersion': 1,
        'name': 'بيتزا',
        'base': {'shape': 'circle', 'rawAssetId': 'base_pizza_regular_raw'},
        'allowedIngredientIds': [k for k, _ in INGREDIENTS],
        # TEMP: calibrated during the P1-B00 drawing prototype.
        'placement': {'strategy': 'scatter', 'params': {
            'pieceSize': 0.13, 'piecesPerUnit': 9, 'radius': 0.74, 'minGap': 0.16,
            # Spread cheeses cover the base instead of sitting as clumps.
            **{f'{k}:{ing}': v for ing in ('mozzarella', 'cheddar')
               for k, v in (('piecesPerUnit', 22), ('pieceSize', 0.2),
                            ('minGap', 0.12), ('radius', 0.72))}}},
        'constraints': {'maxQty': 2},
        'sizes': [
            {'id': 's', 'name': 'صغير', 'scale': 0.8},
            {'id': 'm', 'name': 'وسط', 'scale': 0.9},
            {'id': 'l', 'name': 'كبير', 'scale': 1.0},
        ],
        'optionGroups': [{
            'id': 'dough', 'name': 'العجينة', 'defaultChoiceId': 'regular',
            'choices': [{'id': 'regular', 'name': 'عادية'}],
        }],
        'animation': [
            {'step': 'Oven', 'weight': 3, 'params': {}},
            {'step': 'Swap', 'weight': 1, 'params': {}},
            {'step': 'FlyToCart', 'weight': 1, 'params': {}},
        ],
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
                       'placement.params'],
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
            'id': k, 'name': name, 'assetId': f'ing_{k}', 'assetFiles': variants,
            'extraPrice': TEMP_EXTRA_PRICE, 'isAvailable': True,
            'sizeMultipliers': {},
        })
    dump('tools/seed/pizza_ingredients.json', {
        'temp': True, '_note': TEMP_NOTE, 'tempFields': ['extraPrice'],
        'ingredients': ingredients,
    })

    products = [{
        'id': f'pizza_{pid}', 'categoryId': 'pizza', 'name': name,
        'description': '', 'basePrice': TEMP_BASE_PRICE,
        'imageAssetId': f'final_pizza_{pid}',
        'defaults': [{'ingredientId': d, 'qty': 1, 'removable': True,
                      'refundOnRemove': False, 'refundAmount': 0}
                     for d in defaults],
        'isAvailable': True,
        'sizeDeltas': {'s': 0, 'm': 0, 'l': 0},
        'optionDeltas': {'regular': 0},
        'displayOrder': i,
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
