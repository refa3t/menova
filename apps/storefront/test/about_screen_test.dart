import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/about/presentation/about_screen.dart';

void main() {
  testWidgets('about screen shows developer info from the constants file',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));
    expect(find.text(DeveloperInfo.email), findsOneWidget);
    expect(find.text(DeveloperInfo.phone), findsOneWidget);
    expect(find.text(DeveloperInfo.whatsapp), findsOneWidget);
    expect(find.textContaining(DeveloperInfo.nameAr), findsOneWidget);
  });
}
