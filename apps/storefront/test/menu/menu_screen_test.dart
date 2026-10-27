import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/category_screen.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';
import 'package:storefront/features/menu/presentation/menu_screen.dart';

import 'menu_test.dart' show def, product;

late SharedPreferences prefs;

Widget app(Future<Menu> Function() load, {Widget home = const MenuScreen()}) =>
    ProviderScope(
      overrides: [
        menuProvider.overrideWith((ref) => load()),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        home: Directionality(textDirection: TextDirection.rtl, child: home),
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Menu twoProducts() => Menu.assemble(
    definitions: {'cat_a': def},
    contents: const [
      CategoryContent(categoryId: 'cat_a', isVisible: true, displayOrder: 0),
    ],
    products: [product('p1'), product('p2', order: 1)],
    ingredients: const [],
    assets: const [],
  );

  testWidgets('home lists categories only, not their products', (tester) async {
    await tester.pumpWidget(app(() async => twoProducts()));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.textContaining(AppStrings.productCount(2)), findsOneWidget);
    expect(find.text('p1'), findsNothing);
    expect(find.text(AppStrings.addToCart), findsNothing);
  });

  testWidgets('category page shows its product cards with price', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        () async => twoProducts(),
        home: const CategoryScreen(categoryId: 'cat_a'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('p1'), findsOneWidget);
    expect(find.text('p2'), findsOneWidget);
    expect(find.text(AppStrings.price(100)), findsNWidgets(2));
  });

  testWidgets('unknown category shows a way home', (tester) async {
    await tester.pumpWidget(
      app(
        () async => twoProducts(),
        home: const CategoryScreen(categoryId: 'nope'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.categoryNotFound), findsOneWidget);
  });

  testWidgets('shows retry on load error', (tester) async {
    await tester.pumpWidget(app(() async => throw Exception('offline')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.menuLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  test('price formatting', () {
    expect(AppStrings.priceFrom(10000), 'From EGP 100');
    AppStrings.current = AppLanguage.ar;
    expect(AppStrings.priceFrom(12550), 'يبدأ من 125.50 ج.م');
    AppStrings.current = AppLanguage.en;
  });
}
