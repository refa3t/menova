import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/core/strings/app_strings.dart';
import 'package:storefront/features/builder/presentation/widgets/add_bar.dart';

void main() {
  testWidgets('add bar counts to the new total', (tester) async {
    Widget bar(int total) =>
        MaterialApp(home: Scaffold(body: AddBar(total: total, onAdd: () {})));
    await tester.pumpWidget(bar(10000));
    await tester.pumpAndSettle();
    expect(find.text('${AppStrings.add} · ${AppStrings.price(10000)}'), findsOneWidget);
    await tester.pumpWidget(bar(11500));
    await tester.pumpAndSettle();
    expect(find.text('${AppStrings.add} · ${AppStrings.price(11500)}'), findsOneWidget);
    expect(AppStrings.price(10750), '107.50 ج.م');
  });
}
