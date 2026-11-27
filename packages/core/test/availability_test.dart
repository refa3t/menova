import 'dart:convert';

import 'package:core/core.dart';
import 'package:test/test.dart';

// TEMP: illustrative test fixtures only, not owner-approved values.
Json productJson({bool available = true, int? until}) => {
  'id': 'p1',
  'categoryId': 'cat_a',
  'name': 'TEMP product',
  'basePrice': 10000,
  'imageAssetId': 'img',
  'defaults': <Json>[],
  'isAvailable': available,
  'unavailableUntil': ?until,
};

Json ingredientJson({bool available = true, int? until}) => {
  'id': 'ing_1',
  'name': 'TEMP ingredient',
  'assetId': 'a1',
  'extraPrice': 1500,
  'isAvailable': available,
  'unavailableUntil': ?until,
};

Json settingsJson({int? hour}) => {
  'location': {'lat': 30.0, 'lng': 31.0},
  'delivery': {'perKm': 600, 'minFee': 2500, 'maxDistanceMeters': 15000},
  'dayEndHour': ?hour,
};

Json roundTrip(Json j) => jsonDecode(jsonEncode(j)) as Json;

void main() {
  final now = DateTime(2026, 11, 27, 22);
  final later = DateTime(2026, 11, 28, 4).millisecondsSinceEpoch;
  final earlier = DateTime(2026, 11, 27, 4).millisecondsSinceEpoch;

  group('availableAt', () {
    test('switched off is never available', () {
      expect(
        availableAt(isAvailable: false, unavailableUntil: null, now: now),
        isFalse,
      );
      expect(
        availableAt(isAvailable: false, unavailableUntil: earlier, now: now),
        isFalse,
      );
    });

    test('stopped until a time ahead, then back by itself', () {
      expect(
        availableAt(isAvailable: true, unavailableUntil: later, now: now),
        isFalse,
      );
      final at = DateTime.fromMillisecondsSinceEpoch(later);
      expect(
        availableAt(isAvailable: true, unavailableUntil: later, now: at),
        isTrue,
      );
      expect(
        availableAt(isAvailable: true, unavailableUntil: earlier, now: now),
        isTrue,
      );
    });

    test('earliest pending until ignores past and null', () {
      expect(earliestPendingUntil([null, earlier, later], now), later);
      expect(earliestPendingUntil([later + 1, later], now), later);
      expect(earliestPendingUntil([null, earlier], now), isNull);
    });
  });

  group('Product', () {
    test('round-trips unavailableUntil', () {
      final p = Product.fromJson(productJson(until: later));
      expect(p.unavailableUntil, later);
      expect(Product.fromJson(roundTrip(p.toJson())), p);
      expect(p.isAvailableAt(now), isFalse);
    });

    test('absent means none, and is not written', () {
      final p = Product.fromJson(productJson());
      expect(p.unavailableUntil, isNull);
      expect(p.toJson().containsKey('unavailableUntil'), isFalse);
      expect(p.isAvailableAt(now), isTrue);
      expect(p, isNot(Product.fromJson(productJson(until: later))));
    });
  });

  group('Ingredient', () {
    test('round-trips unavailableUntil', () {
      final i = Ingredient.fromJson(ingredientJson(until: later));
      expect(Ingredient.fromJson(roundTrip(i.toJson())), i);
      expect(i.isAvailableAt(now), isFalse);
      expect(
        i.isAvailableAt(DateTime.fromMillisecondsSinceEpoch(later)),
        isTrue,
      );
    });

    test('absent means none, and is not written', () {
      final i = Ingredient.fromJson(ingredientJson());
      expect(i.unavailableUntil, isNull);
      expect(i.toJson().containsKey('unavailableUntil'), isFalse);
      expect(i.isAvailableAt(now), isTrue);
    });
  });

  group('StoreSettings.dayEndHour', () {
    test('absent means the interim default', () {
      final s = StoreSettings.fromJson(settingsJson());
      expect(s.dayEndHour, defaultDayEndHour);
      expect(defaultDayEndHour, 4);
    });

    test('round-trips', () {
      final s = StoreSettings.fromJson(settingsJson(hour: 2));
      expect(s.dayEndHour, 2);
      final back = StoreSettings.fromJson(roundTrip(s.toJson()));
      expect(back.dayEndHour, 2);
      expect(back.location, s.location);
    });

    test('refuses hours outside 0..23', () {
      expect(
        () => StoreSettings.fromJson(settingsJson(hour: 24)),
        throwsFormatException,
      );
      expect(
        () => StoreSettings.fromJson(settingsJson(hour: -1)),
        throwsFormatException,
      );
    });
  });

  group('nextDayEndAt', () {
    test('today when the hour is still ahead', () {
      expect(
        nextDayEndAt(DateTime(2026, 11, 28, 1, 30), 4),
        DateTime(2026, 11, 28, 4),
      );
    });

    test('tomorrow when the hour has passed or is now', () {
      expect(nextDayEndAt(now, 4), DateTime(2026, 11, 28, 4));
      expect(
        nextDayEndAt(DateTime(2026, 11, 28, 4), 4),
        DateTime(2026, 11, 29, 4),
      );
    });

    test('rolls over the month end', () {
      expect(
        nextDayEndAt(DateTime(2026, 11, 30, 23), 0),
        DateTime(2026, 12, 1),
      );
    });

    test('settings use their hour', () {
      final s = StoreSettings.fromJson(settingsJson(hour: 3));
      expect(s.nextDayEnd(now), DateTime(2026, 11, 28, 3));
    });
  });
}
