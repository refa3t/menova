import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/builder/presentation/widgets/choice_selectors.dart';
import 'package:storefront/features/builder/presentation/widgets/ingredient_grid.dart';

Widget wrap(Widget child) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(body: SingleChildScrollView(child: child)),
  ),
);

IngredientTileData tile(String id, int qty, int def, {bool canRemove = true}) =>
    IngredientTileData(
      id: id,
      name: id,
      imageUrl: 'https://x/$id.webp',
      qty: qty,
      defaultQty: def,
      canRemove: canRemove,
    );

void main() {
  testWidgets(
    'tiles show default check, extra counter and remove only when allowed',
    (tester) async {
      final added = <String>[], removed = <String>[];
      await tester.pumpWidget(
        wrap(
          IngredientGrid(
            items: [
              tile('cheese', 2, 2, canRemove: false),
              tile('olive', 3, 1),
              tile('pepper', 0, 0, canRemove: false),
            ],
            onAdd: added.add,
            onRemove: removed.add,
          ),
        ),
      );
      expect(find.text('✓'), findsOneWidget);
      expect(find.text('×3'), findsOneWidget);
      expect(find.text('−'), findsOneWidget, reason: 'only olive is removable');

      await tester.tap(find.text('pepper'));
      await tester.tap(find.text('−'));
      expect(added, ['pepper']);
      expect(removed, ['olive']);
    },
  );

  testWidgets('size selector hides without sizes and reports selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(SizeSelector(sizes: const [], selectedId: null, onSelected: (_) {})),
    );
    expect(find.byType(ChoiceChip), findsNothing);

    String? picked;
    await tester.pumpWidget(
      wrap(
        SizeSelector(
          sizes: const [
            SizeOption(id: 's', name: 'S'),
            SizeOption(id: 'l', name: 'L'),
          ],
          selectedId: 's',
          onSelected: (id) => picked = id,
        ),
      ),
    );
    await tester.tap(find.text('L'));
    expect(picked, 'l');
  });

  testWidgets('option group selector is generic and hides single choices', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const OptionGroupSelector(
          group: OptionGroup(
            id: 'g',
            name: 'G',
            defaultChoiceId: 'a',
            choices: [OptionChoice(id: 'a', name: 'A')],
          ),
          selectedId: 'a',
          onSelected: print,
        ),
      ),
    );
    expect(find.byType(ChoiceChip), findsNothing);
  });
}
