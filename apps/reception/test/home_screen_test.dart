import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reception/core/strings/app_strings.dart';
import 'package:reception/features/home/presentation/home_screen.dart';

void main() {
  testWidgets('home screen renders heading', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: HomeScreen(),
        ),
      ),
    );
    expect(find.text(AppStrings.homeHeading), findsOneWidget);
  });
}
