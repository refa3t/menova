import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:product_builder/product_builder.dart';

const basic = <String, num>{
  'radius': 0.88,
  'piecesPerUnit': 6,
  'pieceSize': 0.12,
};

/// With `coverage`, the batch sets every unit's piece count: 9 per unit
/// here (the factor is clamped at 1.5), 6 without a batch.
const covered = <String, num>{...basic, 'coverage': 0.5};

void main() {
  CanvasLayer layer(
    String id,
    int qty, {
    int defaultQty = 0,
    List<String>? urls,
  }) => CanvasLayer(
    ingredientId: id,
    imageUrls: urls ?? ['https://example.test/$id.png'],
    qty: qty,
    defaultQty: defaultQty,
    layerOrder: 20,
  );

  Future<void> pump(
    WidgetTester tester,
    List<CanvasLayer> layers, {
    String key = 'canvas',
    double surface = 1,
    Map<String, num> params = basic,
    Map<String, PlacementStrategy> byIngredient = const {},
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
            strategyByIngredient: byIngredient,
            placementParams: params,
            surface: surface,
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

  /// The pieces of [prefix] (an ingredient, or ingredient#unit).
  Map<String, Offset> only(Map<String, Offset> all, String prefix) => {
    for (final e in all.entries)
      if (e.key.startsWith('$prefix#')) e.key: e.value,
  };

  testWidgets('a base with less surface (a thick rim) draws the toppings '
      'inside it, and they move there when the base changes', (tester) async {
    double scale() => tester
        .widget<AnimatedScale>(
          find
              .ancestor(
                of: find.byType(Stack).last,
                matching: find.byType(AnimatedScale),
              )
              .first,
        )
        .scale;
    await pump(tester, [layer('a', 1)]);
    expect(scale(), 1);
    final before = positions(tester);
    await pump(tester, [layer('a', 1)], surface: 0.84);
    expect(scale(), 0.84);
    // The layout itself is kept: the whole layer is drawn smaller.
    expect(positions(tester), before);
  });

  testWidgets('a new key gives a fresh canvas: another product is drawn as '
      'if it were the first', (tester) async {
    await pump(tester, [
      layer('x', 2, defaultQty: 2),
      layer('y', 1, defaultQty: 1),
    ], key: 'one');
    final first = tester.state(find.byType(BuilderCanvas));
    final other = [layer('a', 1, defaultQty: 1), layer('b', 1, defaultQty: 1)];
    await pump(tester, other, key: 'two');
    expect(tester.state(find.byType(BuilderCanvas)), isNot(same(first)));
    final shown = positions(tester);
    expect(
      shown.keys.where((k) => !k.startsWith('a#') && !k.startsWith('b#')),
      isEmpty,
    );

    await pump(tester, const [], key: 'blank');
    await pump(tester, other, key: 'three');
    expect(positions(tester), shown);
  });

  group('joint layout (owner request: toppings spread evenly together)', () {
    testWidgets('adding a topping never moves the pieces already there', (
      tester,
    ) async {
      await pump(tester, [
        layer('a', 1, defaultQty: 1),
        layer('b', 1, defaultQty: 1),
        layer('c', 0),
      ]);
      final before = positions(tester);
      expect(before, hasLength(12));

      await pump(tester, [
        layer('a', 1, defaultQty: 1),
        layer('b', 2, defaultQty: 1),
        layer('c', 1),
      ]);
      await tester.pump(const Duration(seconds: 2));
      final after = positions(tester);
      expect(after, hasLength(24));
      for (final e in before.entries) {
        expect(after[e.key], e.value, reason: e.key);
      }

      // Taken off and put back: the same spots again.
      await pump(tester, [
        layer('a', 1, defaultQty: 1),
        layer('b', 2, defaultQty: 1),
        layer('c', 0),
      ]);
      await tester.pump(const Duration(seconds: 2));
      await pump(tester, [
        layer('a', 1, defaultQty: 1),
        layer('b', 2, defaultQty: 1),
        layer('c', 1),
      ]);
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

    testWidgets('the batch is the defaults, removed ones included: they keep '
        'their spots, undrawn, and come back to them', (tester) async {
      await pump(
        tester,
        [layer('a', 1, defaultQty: 1), layer('b', 2, defaultQty: 2)],
        key: 'page',
        params: covered,
      );
      final page = positions(tester);
      expect(only(page, 'a'), hasLength(9));

      // An edited line without its `a`: the rest where the page has them.
      await pump(
        tester,
        [layer('a', 0, defaultQty: 1), layer('b', 2, defaultQty: 2)],
        key: 'edit',
        params: covered,
      );
      final edit = positions(tester);
      expect(only(edit, 'a'), isEmpty);
      expect(edit, only(page, 'b'));

      // Put back: its own spot.
      await pump(
        tester,
        [layer('a', 1, defaultQty: 1), layer('b', 2, defaultQty: 2)],
        key: 'edit',
        params: covered,
      );
      await tester.pump(const Duration(seconds: 2));
      expect(positions(tester), page);
    });

    testWidgets('a fresh build with extras gives the defaults the spots of the '
        'defaults-only build, and every unit the same piece count', (
      tester,
    ) async {
      List<CanvasLayer> product(int extras) => [
        layer('a', 1, defaultQty: 1),
        layer('b', 1, defaultQty: 1),
        layer('c', extras),
      ];
      await pump(tester, product(0), key: 'page', params: covered);
      final defaults = positions(tester);
      // Added on the product page, one at a time.
      for (final n in [1, 2]) {
        await pump(tester, product(n), key: 'page', params: covered);
        await tester.pump(const Duration(seconds: 2));
      }
      final page = positions(tester);
      expect(only(page, 'c#0'), hasLength(9));
      expect(only(page, 'c#1'), hasLength(9));

      // The cart line, drawn afresh, its layers in another order.
      await pump(
        tester,
        product(2).reversed.toList(),
        key: 'cart',
        params: covered,
      );
      final cart = positions(tester);
      for (final e in defaults.entries) {
        expect(cart[e.key], e.value, reason: e.key);
      }
      // Extras added by ingredient and unit land where a fresh build has
      // them too.
      expect(cart, page);
    });

    testWidgets('with no joint default, the first unit added is no batch: it '
        'gets the count a fresh build gives it', (tester) async {
      const byIngredient = {'choco': SaucePlacement()};
      List<CanvasLayer> crepe(int cheese) => [
        layer('choco', 1, defaultQty: 1),
        layer('cheese', cheese),
      ];
      await pump(
        tester,
        crepe(0),
        key: 'page',
        params: covered,
        byIngredient: byIngredient,
      );
      expect(only(positions(tester), 'cheese'), isEmpty);
      await pump(
        tester,
        crepe(1),
        key: 'page',
        params: covered,
        byIngredient: byIngredient,
      );
      await tester.pump(const Duration(seconds: 2));
      final page = only(positions(tester), 'cheese');
      expect(page, hasLength(6));

      await pump(
        tester,
        crepe(1),
        key: 'cart',
        params: covered,
        byIngredient: byIngredient,
      );
      expect(only(positions(tester), 'cheese'), page);
    });

    testWidgets('a reloaded definition (a new map, same values) moves '
        'nothing; other values lay it out again', (tester) async {
      final layers = [layer('a', 1, defaultQty: 1), layer('b', 1)];
      await pump(tester, layers);
      final before = positions(tester);
      await pump(tester, layers, params: Map.of(basic));
      expect(positions(tester), before);
      await pump(tester, layers, params: {...basic, 'radius': 0.5});
      final after = positions(tester);
      expect(after.keys, before.keys);
      expect(after, isNot(before));
    });

    testWidgets('fewer images than the layout was made with (a reloaded '
        'menu): no error, the remaining ones are drawn', (tester) async {
      List<String> drawn() => [
        for (final i in tester.widgetList<Image>(find.byType(Image)))
          if (i.image case NetworkImage(
            :final url,
          ) when !url.endsWith('base.png'))
            url,
      ];
      await pump(tester, [
        layer(
          'a',
          2,
          defaultQty: 1,
          urls: const [
            'https://example.test/a0.png',
            'https://example.test/a1.png',
            'https://example.test/a2.png',
          ],
        ),
      ]);
      expect(drawn().toSet(), hasLength(greaterThan(1)));

      await pump(tester, [
        layer(
          'a',
          2,
          defaultQty: 1,
          urls: const ['https://example.test/a0.png'],
        ),
      ]);
      expect(tester.takeException(), isNull);
      expect(drawn(), hasLength(12));
      expect(drawn().toSet(), {'https://example.test/a0.png'});

      await pump(tester, [layer('a', 2, defaultQty: 1, urls: const [])]);
      expect(tester.takeException(), isNull);
      expect(drawn(), isEmpty);
    });
  });
}
