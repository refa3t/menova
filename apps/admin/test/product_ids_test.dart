import 'package:admin/core/strings/app_strings.dart';
import 'package:admin/features/catalog/domain/product_ids.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new product ids are stable slugs, unique in their category', () {
    expect(
      newProductId(categoryId: 'pizza', name: 'Chicken Ranch!', taken: {}),
      'pizza_chicken_ranch',
    );
    expect(
      newProductId(
        categoryId: 'pizza',
        name: 'Chicken Ranch',
        taken: {'pizza_chicken_ranch'},
      ),
      'pizza_chicken_ranch_2',
    );
    expect(
      newProductId(categoryId: 'crepe', name: 'كريب', taken: {}),
      'crepe_item',
    );
  });

  test('prices typed in pounds, Arabic or Latin digits', () {
    expect(AppStrings.parseEgp('130'), 13000);
    expect(AppStrings.parseEgp('١٣٥٫٥'), 13550);
    expect(AppStrings.parseEgp('12.25'), 1225);
    expect(AppStrings.parseEgp('12.255'), isNull);
    expect(AppStrings.parseEgp('abc'), isNull);
    expect(AppStrings.egp(13550), '135.50');
    expect(AppStrings.egp(13000), '130');
  });
}
