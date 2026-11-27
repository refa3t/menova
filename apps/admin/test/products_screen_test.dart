import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/features/auth/domain/admin_access.dart';
import 'package:admin/features/auth/presentation/auth_providers.dart';
import 'package:admin/features/catalog/data/audited_writer.dart';
import 'package:admin/features/catalog/data/catalog_providers.dart';
import 'package:admin/features/catalog/domain/catalog_list.dart';
import 'package:admin/features/catalog/presentation/products_screen.dart';
import 'package:category_definitions/category_definitions.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the bulk saves instead of sending them.
class BulkRecorder implements AuditedWriter {
  final saved = <AuditedChange>[];

  @override
  Future<void> write({
    required Granted who,
    required String action,
    required String path,
    required Json after,
    Json? before,
    String? alsoDelete,
  }) async => saved.add(
    AuditedChange(action: action, path: path, after: after, before: before),
  );

  @override
  Future<List<String>> writeAll({
    required Granted who,
    required List<AuditedChange> changes,
    void Function(int done, int total)? onProgress,
  }) async {
    saved.addAll(changes);
    onProgress?.call(changes.length, changes.length);
    return const [];
  }
}

void main() {
  final category = loadBundledDefinitions().definitions.values.first.id;
  Product product(String id, String name, {bool available = true}) => Product(
    id: id,
    categoryId: category,
    name: name,
    description: '',
    basePrice: 13000,
    imageAssetId: 'final_$id',
    defaults: const [],
    isAvailable: available,
  );

  testWidgets('select several products and stop them in one audited bulk', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final writer = BulkRecorder();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          productsProvider.overrideWith(
            (ref) => Stream.value([
              product('a', 'أ'),
              product('b', 'ب'),
              product('c', 'ج', available: false),
            ]),
          ),
          assetsProvider.overrideWith((ref) => Stream.value(const {})),
          draftTargetsProvider.overrideWithValue(const {'products/b'}),
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

    Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
    // Filters.
    await tester.tap(chip(AppStrings.statusStopped));
    await tester.pumpAndSettle();
    expect(find.text('ج'), findsOneWidget);
    expect(find.text('أ'), findsNothing);
    await tester.tap(chip(AppStrings.statusDrafted));
    await tester.pumpAndSettle();
    expect(find.text('ب'), findsOneWidget);
    expect(find.text('أ'), findsNothing);
    await tester.tap(chip(AppStrings.statusAll));
    await tester.pumpAndSettle();

    // Select one, then all shown, then stop.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.selectedCount(1)), findsOneWidget);
    await tester.tap(find.text(AppStrings.selectAllShown));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.selectedCount(3)), findsOneWidget);
    await tester.tap(find.text(AppStrings.stopSelected));
    await tester.pumpAndSettle();
    // c is already stopped: two products to change.
    expect(find.text(AppStrings.confirmStop(2)), findsOneWidget);
    await tester.tap(find.text(AppStrings.confirm));
    await tester.pumpAndSettle();

    expect(
      [for (final c in writer.saved) c.path],
      ['products/a', 'products/b'],
    );
    for (final c in writer.saved) {
      expect(c.action, 'saveProduct');
      expect(c.after['isAvailable'], isFalse);
      expect(c.before?['isAvailable'], isTrue);
    }
    expect(find.text(AppStrings.bulkDone(2)), findsOneWidget);
    expect(find.text(AppStrings.selectedCount(3)), findsNothing);
  });
}
