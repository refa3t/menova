import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

void main() {
  const params = <String, num>{
    'radius': 0.88,
    'piecesPerUnit': 6,
    'pieceSize': 0.12,
  };

  CanvasLayer layer(String id, int qty) => CanvasLayer(
    ingredientId: id,
    imageUrls: ['https://example.test/$id.png'],
    qty: qty,
    layerOrder: 20,
  );

  Future<void> pump(
    WidgetTester tester,
    List<CanvasLayer> layers, {
    String key = 'canvas',
  }) => tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox.square(
          dimension: 400,
          child: BuilderCanvas(
            key: ValueKey(key),
            baseImageUrl: 'https://example.test/base.png',
            layers: layers,
            strategy: const EvenPlacement(),
            placementParams: params,
          ),
        ),
      ),
    ),
  );

  /// Where every piece is, by its key (ingredient#unit#index).
  Map<String, Offset> positions(WidgetTester tester) => {
    for (final p in tester.widgetList<Positioned>(
      find.byWidgetPredicate(
        (w) =>
            w is Positioned &&
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.contains('#'),
      ),
    ))
      (p.key! as ValueKey<String>).value: Offset(p.left!, p.top!),
  };

  group('joint layout (owner request: toppings spread evenly together)', () {
    testWidgets('adding a topping never moves the pieces already there', (
      tester,
    ) async {
      await pump(tester, [layer('a', 1), layer('b', 1), layer('c', 0)]);
      final before = positions(tester);
      expect(before, hasLength(12));

      await pump(tester, [layer('a', 1), layer('b', 1), layer('c', 1)]);
      await tester.pump(const Duration(seconds: 2));
      final after = positions(tester);
      expect(after, hasLength(18));
      for (final e in before.entries) {
        expect(after[e.key], e.value, reason: e.key);
      }

      // Taken off and put back: the same spots again.
      await pump(tester, [layer('a', 1), layer('b', 1), layer('c', 0)]);
      await tester.pump(const Duration(seconds: 2));
      await pump(tester, [layer('a', 1), layer('b', 1), layer('c', 1)]);
      await tester.pump(const Duration(seconds: 2));
      expect(positions(tester), after);
    });

    testWidgets('the product looks the same whatever the order of its layers '
        '(menu card and product page)', (tester) async {
      await pump(tester, [layer('a', 1), layer('b', 2)], key: 'card');
      final one = positions(tester);
      // Another canvas (a new state), its layers in the other order.
      await pump(tester, [layer('b', 2), layer('a', 1)], key: 'page');
      expect(positions(tester), one);
    });
  });
}
