import 'dart:convert';
import 'dart:io';

import 'package:admin/app/admin_shell.dart';
import 'package:admin/app/area_routes.dart';
import 'package:admin/app/router.dart';
import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/core/theme/app_theme.dart';
import 'package:admin/features/audit/domain/audit_entry.dart';
import 'package:admin/features/audit/presentation/audit_screen.dart';
import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:admin/features/auth/presentation/auth_providers.dart';
import 'package:admin/features/catalog/data/catalog_providers.dart';
import 'package:admin/features/drafts/data/drafts_providers.dart';
import 'package:admin/features/drafts/domain/draft.dart';
import 'package:admin/features/offers/data/offers_providers.dart';
import 'package:admin/features/reports/data/sales_report_provider.dart';
import 'package:admin/features/reports/domain/sales_report.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _manager = Granted(
  role: AdminRole.menuManager,
  uid: 'mgr1',
  email: 'manager@example.com',
);
const _owner = Granted(
  role: AdminRole.owner,
  uid: 'own1',
  email: 'owner@example.com',
);

Widget _app(Widget home, {Granted who = _manager}) => ProviderScope(
  overrides: [adminAccessProvider.overrideWith((ref) => Stream.value(who))],
  child: MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildAppTheme(),
    home: home,
  ),
);

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

ListTile _entry(WidgetTester tester, String label) => tester.widget<ListTile>(
  find.ancestor(of: find.text(label), matching: find.byType(ListTile)),
);

/// The seeded menu (tools/seed), so the phone check uses real names.
Json _seed(String file) =>
    jsonDecode(File('../../tools/seed/$file').readAsStringSync()) as Json;

void main() {
  testWidgets('the side navigation shows only the role\'s sections', (
    tester,
  ) async {
    _size(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _app(
        AdminShell(
          location: '/products/p1',
          onSignOut: () {},
          child: const Scaffold(body: Text('page')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final a in AdminArea.values) {
      expect(
        find.text(AppStrings.area(a)),
        canManage(AdminRole.menuManager, a) ? findsOneWidget : findsNothing,
        reason: a.name,
      );
    }
    expect(find.text(AppStrings.home), findsOneWidget);
    expect(find.text('page'), findsOneWidget);
    // A product page highlights its section.
    expect(_entry(tester, AppStrings.area(AdminArea.products)).selected, true);
    expect(_entry(tester, AppStrings.home).selected, isFalse);
    // The user, sign out and the developer credit.
    expect(find.text('manager@example.com'), findsOneWidget);
    expect(find.text(AppStrings.role(AdminRole.menuManager)), findsOneWidget);
    expect(find.text(AppStrings.signOut), findsOneWidget);
    expect(find.text(AppStrings.credit), findsOneWidget);
  });

  testWidgets('the owner sees every section', (tester) async {
    _size(tester, const Size(1280, 900));
    await tester.pumpWidget(
      _app(
        AdminShell(location: '/', onSignOut: () {}, child: const SizedBox()),
        who: _owner,
      ),
    );
    await tester.pumpAndSettle();
    for (final a in AdminArea.values) {
      expect(find.text(AppStrings.area(a)), findsOneWidget, reason: a.name);
    }
    expect(_entry(tester, AppStrings.home).selected, isTrue);
  });

  testWidgets('on a phone the navigation opens from the menu button', (
    tester,
  ) async {
    _size(tester, const Size(375, 812));
    var signedOut = false;
    await tester.pumpWidget(
      _app(
        AdminShell(
          location: '/offers',
          onSignOut: () => signedOut = true,
          child: const Scaffold(body: Text('page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // Closed: only the bar and the page.
    expect(find.text(AppStrings.area(AdminArea.products)), findsNothing);
    final menu = find.byTooltip(AppStrings.openNav);
    expect(tester.getSize(menu).height, greaterThanOrEqualTo(44));

    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.area(AdminArea.products)), findsOneWidget);
    expect(find.text(AppStrings.area(AdminArea.reports)), findsNothing);
    expect(_entry(tester, AppStrings.area(AdminArea.offers)).selected, true);

    await tester.tap(find.text(AppStrings.signOut));
    await tester.pumpAndSettle();
    expect(signedOut, isTrue);
    expect(find.text(AppStrings.area(AdminArea.products)), findsNothing);
  });

  for (final width in [375.0, 768.0, 1280.0]) {
    testWidgets('every section fits at ${width.toInt()}px', (tester) async {
      // Tall, so lazy lists build every row.
      _size(tester, Size(width, 5000));
      final products = [
        for (final f in ['pizza_products.json', 'crepe_products.json'])
          for (final p in _seed(f)['products'] as List)
            Product.fromJson(p as Json),
      ];
      final ingredients = {
        for (final f in ['pizza_ingredients.json', 'crepe_ingredients.json'])
          for (final i in _seed(f)['ingredients'] as List)
            (i as Json)['id'] as String: Ingredient.fromJson(i),
      };
      final assets = {
        for (final i in ingredients.values)
          i.assetId: Asset(
            id: i.assetId,
            kind: 'ingredient',
            name: i.name,
            publicId: i.assetId,
            secureUrl: 'https://example.invalid/${i.assetId}.webp',
            version: 1,
            layerOrder: 1,
            allowedCategoryIds: const ['pizza'],
            variants: const [
              'https://example.invalid/a.webp',
              'https://example.invalid/b.webp',
            ],
          ),
      };
      final margherita = products.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAccessProvider.overrideWith((ref) => Stream.value(_owner)),
            productsProvider.overrideWith((ref) => Stream.value(products)),
            ingredientsProvider.overrideWith(
              (ref) => Stream.value(ingredients),
            ),
            assetsProvider.overrideWith((ref) => Stream.value(assets)),
            categoryContentProvider.overrideWith(
              (ref) => Stream.value([
                for (final (i, id) in ['pizza', 'crepe'].indexed)
                  CategoryContent(
                    categoryId: id,
                    isVisible: true,
                    displayOrder: i,
                  ),
              ]),
            ),
            storeSettingsProvider.overrideWith(
              (ref) => Stream.value(
                StoreSettings.fromJson(_seed('store_settings.json')),
              ),
            ),
            draftsProvider.overrideWith(
              (ref) => Stream.value([
                Draft(
                  target: 'products/${margherita.id}',
                  kind: DraftKind.product,
                  changes: const {'basePrice': 14000},
                  base: {'basePrice': margherita.basePrice},
                  byEmail: 'manager@example.com',
                  at: DateTime(2026, 11, 1),
                ),
              ]),
            ),
            offersProvider.overrideWith(
              (ref, list) => Stream.value([
                list == OfferList.coupons
                    ? const Offer(
                        id: 'EID26',
                        name: 'خصم العيد',
                        kind: OfferKind.percent,
                        value: 15,
                        code: 'EID26',
                        maxUses: 100,
                      )
                    : const Offer(
                        id: 'o1',
                        name: 'توصيل مجاني فوق 300 جنيه',
                        kind: OfferKind.freeDelivery,
                        minSubtotal: 30000,
                      ),
              ]),
            ),
            auditProvider.overrideWith(
              (ref) => Stream.value([
                AuditEntry(
                  id: 'a1',
                  action: 'saveProduct',
                  target: 'products/${margherita.id}',
                  by: 'own1',
                  byEmail: 'owner@example.com',
                  at: DateTime(2026, 11, 1),
                  before: const {'basePrice': 13000},
                  after: {'name': margherita.name, 'basePrice': 14000},
                ),
              ]),
            ),
            salesReportProvider.overrideWith((ref, days) async {
              final p = lastDays(DateTime(2026, 11, 1, 12), days);
              return SalesReport(
                from: p.from,
                to: p.to,
                totals: const SalesTotals(orders: 1, items: 13000),
                excluded: 0,
                unreadable: 0,
                days: [PeriodSales(p.from, const SalesTotals())],
                weeks: [PeriodSales(weekStart(p.from), const SalesTotals())],
                bestSellers: const [],
                addOns: const [],
              );
            }),
          ],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              locale: const Locale('ar'),
              supportedLocales: const [Locale('ar')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              theme: buildAppTheme(),
              routerConfig: ref.watch(routerProvider),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final router = ProviderScope.containerOf(
        tester.element(find.byType(AdminShell)),
      ).read(routerProvider);

      for (final path in [
        '/',
        ...areaRoutes.values,
        '/products/${margherita.id}',
        '/products/new',
        '/ingredients/${ingredients.keys.first}',
        '/offers/new',
        '/offers/coupon/EID26',
      ]) {
        router.go(path);
        await tester.pumpAndSettle();
        // An overflow or a layout error fails the test on its own.
        expect(find.byType(AdminShell), findsOneWidget, reason: path);
        expect(tester.takeException(), isNull, reason: path);
      }
    });
  }
}
