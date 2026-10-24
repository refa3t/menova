// P1-H03: realistic animation checks on the real builder screen.
import 'package:animation/animation.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/builder/presentation/builder_screen.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';

// TEMP fixtures, not owner data. Image URLs are unreachable in tests, which
// doubles as the "animation assets failed to load" case (AC-30).
const def = CategoryDefinition(
  id: 'cat',
  definitionVersion: 1,
  name: 'C',
  base: BaseSpec(shape: 'circle', rawAssetId: 'base'),
  allowedIngredientIds: ['cheese'],
  placement: PlacementSpec(strategy: 'rings'),
  constraints: CustomizationConstraints(maxQty: 2),
  sizes: [SizeOption(id: 's', name: 'S')],
  optionGroups: [],
  animation: [
    StepSpec(
      step: 'Oven',
      weight: 2200,
      params: {
        'durationMs': 2200,
        'images': {'hearth': 'oven_hearth'},
      },
    ),
    StepSpec(step: 'Swap', weight: 300, params: {'durationMs': 300}),
    StepSpec(step: 'FlyToCart', weight: 900, params: {'durationMs': 900}),
  ],
  assetSpecs: {},
);

const product = Product(
  id: 'p1',
  categoryId: 'cat',
  name: 'P',
  description: '',
  basePrice: 10000,
  imageAssetId: 'final_p1',
  isAvailable: true,
  defaults: [
    ProductIngredient(ingredientId: 'cheese', qty: 1, removable: true),
  ],
);

Asset asset(String id, String kind) => Asset(
  id: id,
  kind: kind,
  name: id,
  publicId: id,
  secureUrl: 'https://invalid.test/$id.webp',
  version: 1,
  layerOrder: 0,
  allowedCategoryIds: const ['cat'],
);

Future<ProviderContainer> pumpBuilder(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final menu = Menu.assemble(
    definitions: {'cat': def},
    contents: const [
      CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
    ],
    products: const [product],
    ingredients: const [
      Ingredient(
        id: 'cheese',
        name: 'Cheese',
        assetId: 'ing_cheese',
        extraPrice: 1500,
        isAvailable: true,
      ),
    ],
    assets: [
      asset('base', 'base'),
      asset('ing_cheese', 'ingredient'),
      asset('oven_hearth', 'animation'),
    ],
  );
  final container = ProviderContainer(
    overrides: [
      menuProvider.overrideWith((ref) async => menu),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  final router = GoRouter(
    initialLocation: '/product/p1',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (_, s) => BuilderScreen(productId: s.pathParameters['id']!),
      ),
    ],
  );
  addTearDown(container.dispose);
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

Finder addButton() => find.textContaining('${AppStrings.addToCart} · ');

void main() {
  testWidgets('AC-30: failing animation assets still finish; item intact', (
    tester,
  ) async {
    final c = await pumpBuilder(tester);
    await tester.tap(addButton());
    await tester.pump();
    expect(c.read(cartProvider).lines, hasLength(1), reason: 'committed first');
    expect(find.byType(StepRunner), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 3500));
    await tester.pump();
    expect(find.byType(StepRunner), findsNothing);
    expect(c.read(cartProvider).lines, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1300));
  });

  testWidgets('AC-17: leaving mid-animation cancels cleanly, no duplicate', (
    tester,
  ) async {
    final c = await pumpBuilder(tester);
    await tester.tap(addButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(StepRunner), findsOneWidget);
    GoRouter.of(tester.element(find.byType(BuilderScreen))).go('/');
    await tester.pumpAndSettle();
    expect(find.byType(StepRunner), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(c.read(cartProvider).lines, hasLength(1));
  });

  testWidgets('AC-15: reduced motion runs a short sequence (≤ 600ms)', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final c = await pumpBuilder(tester);
    await tester.tap(addButton());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 650));
    await tester.pump();
    expect(find.byType(StepRunner), findsNothing);
    expect(c.read(cartProvider).lines, hasLength(1));
    await tester.pump(const Duration(milliseconds: 1300));
  });
}
