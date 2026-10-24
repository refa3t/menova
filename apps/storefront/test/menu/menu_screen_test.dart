import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';
import 'package:storefront/features/menu/presentation/menu_screen.dart';

import 'menu_test.dart' show def, product;

Widget app(Future<Menu> Function() load) => ProviderScope(
      overrides: [menuProvider.overrideWith((ref) => load())],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: MenuScreen(),
        ),
      ),
    );

void main() {
  testWidgets('shows category chip and product cards with price',
      (tester) async {
    final menu = Menu.assemble(
      definitions: {'cat_a': def},
      contents: const [
        CategoryContent(categoryId: 'cat_a', isVisible: true, displayOrder: 0),
      ],
      products: [product('p1'), product('p2', order: 1)],
      ingredients: const [],
      assets: const [],
    );
    await tester.pumpWidget(app(() async => menu));
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('p1'), findsOneWidget);
    expect(find.text('p2'), findsOneWidget);
    expect(find.text(AppStrings.priceFrom(100)), findsNWidgets(2));
  });

  testWidgets('shows retry on load error', (tester) async {
    await tester.pumpWidget(app(() async => throw Exception('offline')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.menuLoadError), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });

  test('price formatting', () {
    expect(AppStrings.priceFrom(10000), 'يبدأ من 100 ج.م');
    expect(AppStrings.priceFrom(12550), 'يبدأ من 125.50 ج.م');
  });
}
