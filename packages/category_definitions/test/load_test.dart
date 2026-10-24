import 'package:category_definitions/category_definitions.dart';
import 'package:test/test.dart';

void main() {
  test('bundled pizza definition loads', () {
    final r = loadBundledDefinitions();
    expect(r.rejected, isEmpty);
    expect(r.definitions['pizza']!.allowedIngredientIds, hasLength(38));
  });
}
