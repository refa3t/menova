// How the storefront feeds the canvas: previews keyed per product and
// selection, the defaults as the joint batch, and the capture for the
// add-to-cart sequence. TEMP fixtures, not owner data.
import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/builder/presentation/builder_screen.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';
import 'package:storefront/features/menu/presentation/product_preview.dart';

import '../cart/cart_test.dart' show ing;

CategoryDefinition definition({
  List<StepSpec> animation = const [StepSpec(step: 'Oven')],
  double surface = 1,
  double sizeScale = 1,
}) => CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'C',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base', surface: surface),
  allowedIngredientIds: const ['cheese', 'olive', 'pepper'],
  // With `coverage`, the batch sets every unit's piece count.
  placement: const PlacementSpec(
    strategy: 'even',
    params: {'piecesPerUnit': 6, 'pieceSize': 0.12, 'coverage': 0.5},
  ),
  constraints: const CustomizationConstraints(maxQty: 2),
  sizes: [SizeOption(id: 's', name: 'S', scale: sizeScale)],
  optionGroups: const [],
  animation: animation,
  assetSpecs: const {},
);

const p1 = Product(
  id: 'p1',
  categoryId: 'cat',
  name: 'P1',
  description: '',
  basePrice: 10000,
  imageAssetId: 'final_p1',
  isAvailable: true,
  defaults: [
    ProductIngredient(ingredientId: 'cheese', qty: 1, removable: true),
    ProductIngredient(ingredientId: 'olive', qty: 1, removable: true),
  ],
);

const p2 = Product(
  id: 'p2',
  categoryId: 'cat',
  name: 'P2',
  description: '',
  basePrice: 10000,
  imageAssetId: 'final_p2',
  isAvailable: true,
  defaults: [
    ProductIngredient(ingredientId: 'pepper', qty: 2, removable: true),
  ],
);

Asset asset(String id, String kind) => Asset(
  id: id,
  kind: kind,
  name: id,
  publicId: id,
  secureUrl: 'https://invalid.test/$id.webp',
  version: 1,
  layerOrder: kind == 'base' ? 0 : 20,
  allowedCategoryIds: const ['cat'],
);

Menu menuOf(CategoryDefinition def) => Menu.assemble(
  definitions: {'cat': def},
  contents: const [
    CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
  ],
  products: const [p1, p2],
  ingredients: [ing('cheese'), ing('olive'), ing('pepper')],
  assets: [
    asset('base', 'base'),
    for (final id in ['cheese', 'olive', 'pepper'])
      asset('a_$id', 'ingredient'),
  ],
);

/// Where every piece is, by its key (ingredient#unit#index).
Map<String, Offset> positions(WidgetTester tester) => {
  for (final p in tester.widgetList<Positioned>(
    find.byWidgetPredicate(
      (w) =>
          w is Positioned &&
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.contains('#'),
    ),
  ))
    (p.key! as ValueKey<String>).value: Offset(p.left!, p.top!),
};

Map<String, Offset> only(Map<String, Offset> all, String id) => {
  for (final e in all.entries)
    if (e.key.startsWith('$id#')) e.key: e.value,
};

void main() {
  group('ProductPreview', () {
    final def = definition();
    final menu = menuOf(def);

    Future<void> preview(
      WidgetTester tester,
      Product product, {
      Selection? selection,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox.square(
            dimension: 300,
            child: ProductPreview(
              menu: menu,
              definition: def,
              product: product,
              selection: selection,
            ),
          ),
        ),
      ),
    );

    testWidgets('a place reused for another product (a filtered grid) draws '
        'it on a fresh canvas, as if it were shown first', (tester) async {
      await preview(tester, p1);
      final first = tester.state(find.byType(BuilderCanvas));
      await preview(tester, p2);
      expect(tester.state(find.byType(BuilderCanvas)), isNot(same(first)));
      final reused = positions(tester);
      expect(only(reused, 'cheese'), isEmpty);

      await tester.pumpWidget(const SizedBox());
      await preview(tester, p2);
      expect(positions(tester), reused);
    });

    testWidgets('a cart line without a default and with an extra keeps the '
        'other defaults where the menu card has them', (tester) async {
      await preview(tester, p1);
      final card = positions(tester);
      final line = Selection.initial(p1, definitionVersion: 1).copyWith(
        sizeId: 's',
        ingredients: {'cheese': 1, 'olive': 0, 'pepper': 1},
      );
      await preview(tester, p1, selection: line);
      final cart = positions(tester);
      expect(only(cart, 'olive'), isEmpty);
      expect(only(cart, 'cheese'), only(card, 'cheese'));
      // The extra takes the batch's piece count, as on the product page.
      expect(only(cart, 'pepper'), hasLength(only(card, 'cheese').length));
      // Every default is a layer, with what the product comes with.
      final layers = tester
          .widget<BuilderCanvas>(find.byType(BuilderCanvas))
          .layers;
      expect(
        {for (final l in layers) l.ingredientId: (l.qty, l.defaultQty)},
        {'cheese': (1, 1), 'olive': (0, 1), 'pepper': (1, 0)},
      );
    });
  });

  group('builder screen', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      CategoryDefinition def,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          menuProvider.overrideWith((ref) async => menuOf(def)),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BuilderScreen(productId: 'p1')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      return container;
    }

    /// Presses "Add" and returns what the running sequence was given.
    Future<AnimStepInput> add(WidgetTester tester) async {
      await tester.tap(find.textContaining('${AppStrings.addToCart} · '));
      await tester.pump();
      final input = tester.widget<StepRunner>(find.byType(StepRunner)).input;
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 2));
      return input;
    }

    testWidgets('the canvas gets each ingredient\'s default quantity', (
      tester,
    ) async {
      await open(tester, definition());
      final layers = tester
          .widget<BuilderCanvas>(find.byType(BuilderCanvas))
          .layers;
      expect(
        {for (final l in layers) l.ingredientId: l.defaultQty},
        {'cheese': 1, 'olive': 1, 'pepper': 0},
      );
    });

    testWidgets('no step shows the pieces apart (a pizza): none captured', (
      tester,
    ) async {
      await open(
        tester,
        definition(
          animation: const [
            StepSpec(step: 'Oven', weight: 2200, params: {'durationMs': 2200}),
            StepSpec(step: 'Swap', weight: 300, params: {'durationMs': 300}),
            StepSpec(
              step: 'FlyToCart',
              weight: 900,
              params: {'durationMs': 900},
            ),
          ],
        ),
      );
      final input = await add(tester);
      expect(input.contents, isNull);
    });

    testWidgets('a wrap\'s open end gets the pieces, scaled by the size and '
        'the base\'s surface like the full snapshot', (tester) async {
      final c = await open(
        tester,
        definition(
          surface: 0.84,
          sizeScale: 1.2,
          animation: const [
            StepSpec(
              step: 'Fold',
              weight: 650,
              params: {
                'durationMs': 650,
                'stage': 1,
                'lines': [
                  [0.0, 0.5, 1.0, 0.5],
                ],
                'opening': {
                  'ellipse': [0.5, 0.3, 0.2, 0.06],
                  'contents': [0.2, 0.4, 0.8, 0.7],
                },
              },
            ),
            StepSpec(
              step: 'FlyToCart',
              weight: 300,
              params: {'durationMs': 300},
            ),
          ],
        ),
      );
      final input = await add(tester);
      expect(c.read(cartProvider).lines, hasLength(1));
      final contents = input.contents;
      expect(contents, isA<Transform>());
      expect(
        (contents! as Transform).transform.getMaxScaleOnAxis(),
        closeTo(1.2 * 0.84, 1e-9),
      );
    });
  });
}
