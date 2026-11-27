import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:admin/features/auth/presentation/auth_providers.dart';
import 'package:admin/features/catalog/data/audited_writer.dart';
import 'package:admin/features/catalog/data/catalog_providers.dart';
import 'package:admin/features/catalog/domain/catalog_list.dart';
import 'package:admin/features/catalog/presentation/products_screen.dart';
import 'package:admin/features/drafts/domain/draft.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_list_test.dart' show ingredient, product;
import 'products_screen_test.dart' show BulkRecorder;

// «إيقاف لنهاية اليوم»: stopped now, available again by itself at the end
// of the business day the owner set.

void main() {
  final now = DateTime(2026, 11, 27, 22);
  final until = DateTime(2026, 11, 28, 4).millisecondsSinceEpoch;

  test('the day end is the next dayEndHour in local time', () {
    expect(dayEndUntil(now, 4), until);
    expect(
      dayEndUntil(DateTime(2026, 11, 28, 1), 4),
      DateTime(2026, 11, 28, 4).millisecondsSinceEpoch,
    );
    expect(
      dayEndUntil(DateTime(2026, 11, 28, 4), 4),
      DateTime(2026, 11, 29, 4).millisecondsSinceEpoch,
    );
  });

  test('stop for the day keeps it switched on with a time', () {
    final p = product('p1');
    final c = productStopUntilChanges([p], until).single;
    expect(c.action, 'saveProduct');
    expect(c.before, p.toJson());
    expect(c.after, {...p.toJson(), 'unavailableUntil': until});
    // Already stopped until that time: nothing to save.
    final stopped = Product.fromJson(c.after);
    expect(productStopUntilChanges([stopped], until), isEmpty);

    final i = ingredient('i1');
    expect(ingredientStopUntilChanges([i], until).single.after, {
      ...i.toJson(),
      'unavailableUntil': until,
    });
  });

  test('start clears the time; stop is until started again', () {
    final stopped = Product.fromJson({
      ...product('p1').toJson(),
      'unavailableUntil': until,
    });
    final start = productAvailabilityChanges([stopped], true).single;
    expect(start.after['isAvailable'], isTrue);
    expect(start.after.containsKey('unavailableUntil'), isFalse);
    final stop = productAvailabilityChanges([stopped], false).single;
    expect(stop.after['isAvailable'], isFalse);
    expect(stop.after.containsKey('unavailableUntil'), isFalse);
    // A plain available product needs no start.
    expect(productAvailabilityChanges([product('p2')], true), isEmpty);

    final ing = Ingredient.fromJson({
      ...ingredient('i1').toJson(),
      'unavailableUntil': until,
    });
    final started = ingredientAvailabilityChanges([ing], true).single;
    expect(started.after.containsKey('unavailableUntil'), isFalse);
  });

  test('a row stopped until a time counts as stopped, then as available', () {
    final all = [
      product('a'),
      Product.fromJson({...product('b').toJson(), 'unavailableUntil': until}),
    ];
    List<String> ids(StatusFilter s, DateTime at) => [
      for (final p in filterProducts(all, status: s, now: at)) p.id,
    ];
    expect(ids(StatusFilter.stopped, now), ['b']);
    expect(ids(StatusFilter.available, now), ['a']);
    final later = DateTime.fromMillisecondsSinceEpoch(until);
    expect(ids(StatusFilter.stopped, later), isEmpty);

    final ings = [
      Ingredient.fromJson({
        ...ingredient('i1').toJson(),
        'unavailableUntil': until,
      }),
    ];
    expect(
      filterIngredients(ings, status: StatusFilter.stopped, now: now),
      hasLength(1),
    );
    expect(
      pendingUntil(isAvailable: true, unavailableUntil: until, now: now),
      DateTime.fromMillisecondsSinceEpoch(until),
    );
    expect(
      pendingUntil(isAvailable: true, unavailableUntil: until, now: later),
      isNull,
    );
  });

  test('the row label reads «موقوف حتى 4:00 ص»', () {
    expect(
      AppStrings.stoppedUntil(DateTime.fromMillisecondsSinceEpoch(until)),
      'موقوف حتى 4:00 ص',
    );
    expect(AppStrings.hourLabel(0), '12:00 ص');
    expect(AppStrings.hourLabel(13), '1:00 م');
  });

  test('a draft saved without touching availability keeps the time', () {
    final live = Product.fromJson({
      ...product('p1').toJson(),
      'unavailableUntil': until,
    }).toJson();
    // The edit screen keeps the live time when the switch is not used.
    final edited = {...live, 'basePrice': 14000};
    final d = diffRecord(live, edited);
    expect(d.changes.keys, ['basePrice']);
    final draft = Draft(
      target: 'products/p1',
      kind: DraftKind.product,
      changes: d.changes,
      base: d.base,
    );
    // Stopped later (another time): publishing keeps the live stop.
    final later = {...live, 'unavailableUntil': until + 1000};
    expect(draft.applyTo(later)['unavailableUntil'], until + 1000);
  });

  testWidgets('stop one product and a selection for the day, audited', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final category = loadBundledDefinitions().definitions.values.first.id;
    Product p(String id, String name) => Product(
      id: id,
      categoryId: category,
      name: name,
      description: '',
      basePrice: 13000,
      imageAssetId: 'final_$id',
      defaults: const [],
      isAvailable: true,
    );
    final writer = BulkRecorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(
            (ref) => Stream.value([p('a', 'أ'), p('b', 'ب')]),
          ),
          assetsProvider.overrideWith((ref) => Stream.value(const {})),
          draftTargetsProvider.overrideWithValue(const {}),
          storeSettingsProvider.overrideWith(
            (ref) => Stream.value(
              const StoreSettings(
                location: LatLng(30, 31),
                delivery: DeliverySettings(
                  perKm: 600,
                  minFee: 2500,
                  maxDistanceMeters: 15000,
                ),
                dayEndHour: 3,
              ),
            ),
          ),
          adminAccessProvider.overrideWith(
            (ref) => Stream.value(
              const Granted(role: AdminRole.menuManager, uid: 'mgr1'),
            ),
          ),
          auditedWriterProvider.overrideWithValue(writer),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          supportedLocales: [Locale('ar')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: ProductsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(ProductsScreen)),
    ).listen(adminAccessProvider, (_, _) {});
    await tester.pumpAndSettle();

    final expected = dayEndUntil(DateTime.now(), 3);

    // One row, from its menu.
    await tester.tap(find.byTooltip(AppStrings.moreActions).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.stopForDay));
    await tester.pumpAndSettle();
    expect(writer.saved, hasLength(1));
    expect(writer.saved.single.path, 'products/a');
    expect(writer.saved.single.after['unavailableUntil'], expected);
    expect(writer.saved.single.after['isAvailable'], isTrue);

    // A selection, from the bulk bar (the fake writer leaves the list as
    // it was, so both are stopped).
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.selectAllShown));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.stopForDay));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.confirm));
    await tester.pumpAndSettle();
    expect(
      [for (final c in writer.saved.skip(1)) c.path],
      ['products/a', 'products/b'],
    );
    for (final c in writer.saved.skip(1)) {
      expect(c.after['unavailableUntil'], expected);
    }
  });
}
