import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:admin/features/auth/presentation/auth_providers.dart';
import 'package:admin/features/catalog/data/audited_writer.dart';
import 'package:admin/features/offers/data/offers_providers.dart';
import 'package:admin/features/offers/presentation/offer_edit_screen.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Records the audited writes instead of sending them.
class RecordingWriter implements AuditedWriter {
  final writes = <(String, String, Json)>[];

  @override
  Future<void> write({
    required Granted who,
    required String action,
    required String path,
    required Json after,
    Json? before,
  }) async => writes.add((action, path, after));
}

void main() {
  testWidgets('a coupon is checked like the rules before an audited save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final writer = RecordingWriter();
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Text('home'),
          routes: [
            GoRoute(
              path: 'new',
              builder: (context, state) =>
                  const OfferEditScreen(list: OfferList.coupons),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          offersProvider.overrideWith(
            (ref, list) => Stream.value(const [
              Offer(
                id: 'TAKEN',
                name: 'TEMP',
                kind: OfferKind.amount,
                value: 1000,
                code: 'TAKEN',
              ),
            ]),
          ),
          adminAccessProvider.overrideWith(
            (ref) => Stream.value(
              const Granted(role: AdminRole.menuManager, uid: 'mgr1'),
            ),
          ),
          auditedWriterProvider.overrideWithValue(writer),
        ],
        child: MaterialApp.router(
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          routerConfig: router,
        ),
      ),
    );
    router.push('/new');
    await tester.pumpAndSettle();
    // The app's router keeps the signed-in user loaded; here, a listener.
    ProviderScope.containerOf(
      tester.element(find.byType(OfferEditScreen)),
    ).listen(adminAccessProvider, (_, _) {});
    await tester.pumpAndSettle();

    Finder field(String label) => find.widgetWithText(TextField, label);
    await tester.enterText(field(AppStrings.couponCodeLabel), 'taken');
    await tester.enterText(field(AppStrings.percentValue), '150');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();
    expect(find.text('• ${AppStrings.codeTaken}'), findsOneWidget);
    expect(find.text('• ${AppStrings.issue('value')}'), findsOneWidget);
    expect(find.text('• ${AppStrings.issue('name')}'), findsOneWidget);
    expect(writer.writes, isEmpty);

    await tester.enterText(field(AppStrings.couponCodeLabel), 'eid 26');
    await tester.enterText(field(AppStrings.nameAr), 'خصم العيد');
    await tester.enterText(field(AppStrings.percentValue), '15');
    await tester.enterText(field(AppStrings.maxDiscountField), '50');
    await tester.enterText(field(AppStrings.maxUsesField), '١٠٠');
    await tester.tap(find.text(AppStrings.save));
    await tester.pumpAndSettle();

    final (action, path, after) = writer.writes.single;
    expect(action, 'saveCoupon');
    expect(path, 'coupons/EID26');
    expect(after['code'], 'EID26');
    expect(after['kind'], 'percent');
    expect(after['value'], 15);
    expect(after['maxDiscount'], 5000);
    expect(after['maxUses'], 100);
    expect(after['uses'], 0);
    expect(after['isActive'], isTrue);
    expect(find.text('home'), findsOneWidget, reason: 'back after saving');
  });
}
