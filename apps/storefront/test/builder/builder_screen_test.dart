import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/builder/presentation/builder_screen.dart';
import 'package:storefront/features/cart/presentation/cart_providers.dart';
import 'package:storefront/features/menu/domain/menu.dart';
import 'package:storefront/features/menu/presentation/menu_providers.dart';

import '../cart/cart_test.dart' show def, product, ing;

void main() {
  testWidgets('builder shows the add bar with the live price', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final menu = Menu.assemble(
      definitions: {'cat': def},
      contents: const [
        CategoryContent(categoryId: 'cat', isVisible: true, displayOrder: 0),
      ],
      products: const [product],
      ingredients: [ing('cheese'), ing('olive'), ing('pepper')],
      assets: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuProvider.overrideWith((ref) async => menu),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(home: BuilderScreen(productId: 'p1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('${AppStrings.add} · ${AppStrings.price(10000)}'),
      findsOneWidget,
    );
  });
}
