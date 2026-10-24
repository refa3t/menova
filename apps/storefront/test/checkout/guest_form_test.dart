import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storefront/features/checkout/domain/guest_form.dart';

void main() {
  test('Egyptian mobile numbers, including Arabic digits', () {
    expect(GuestValidation.phone('01012345678'), isNull);
    expect(GuestValidation.phone('0155 540 3974'), isNull);
    expect(GuestValidation.phone('٠١١٠٠٥٠٨١٠٨'), isNull);
    expect(GuestValidation.phone('0131234567'), 'phone');
    expect(GuestValidation.phone('0101234567'), 'phone');
  });

  test('address required only for delivery', () {
    expect(GuestValidation.address('', Fulfillment.pickup), isNull);
    expect(GuestValidation.address('', Fulfillment.delivery), 'address');
    expect(
      GuestValidation.address('شارع 9 المعادي', Fulfillment.delivery),
      isNull,
    );
  });

  test('name needs at least two characters', () {
    expect(GuestValidation.name(' م '), 'name');
    expect(GuestValidation.name('محمد'), isNull);
  });
}
