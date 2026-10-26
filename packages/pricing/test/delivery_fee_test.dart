import 'package:core/core.dart';
import 'package:pricing/pricing.dart';
import 'package:test/test.dart';

void main() {
  const s = DeliverySettings(
    perKm: 600,
    minFee: 2500,
    maxDistanceMeters: 15000,
  );

  test('started kilometers are charged in full', () {
    expect(deliveryFee(4300, s), 3000); // 5 km × 6
    expect(deliveryFee(5000, s), 3000);
    expect(deliveryFee(5001, s), 3600);
  });

  test('never below the minimum fee', () {
    expect(deliveryFee(0, s), 2500);
    expect(deliveryFee(1200, s), 2500); // 2 km = 12 < 25
    expect(deliveryFee(4000, s), 2500); // 4 km = 24 < 25
  });

  test('the maximum distance is inclusive, beyond is rejected', () {
    expect(deliveryFee(15000, s), 9000);
    expect(
      () => deliveryFee(15001, s),
      throwsA(
        isA<PricingException>().having((e) => e.code, 'code', 'outOfRange'),
      ),
    );
  });

  test('haversine is a lower bound sanity check', () {
    const a = LatLng(30.4468569, 31.1910437);
    const b = LatLng(30.4600, 31.1800);
    expect(haversineMeters(a, b), closeTo(1797, 30));
    expect(haversineMeters(a, a), 0);
  });
}
