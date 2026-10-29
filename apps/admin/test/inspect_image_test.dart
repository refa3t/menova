import 'dart:typed_data';

import 'package:admin/features/assets/domain/inspect_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('any non-opaque pixel counts as transparency', () {
    expect(
      hasTransparentPixel(Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 255])),
      isFalse,
    );
    expect(
      hasTransparentPixel(Uint8List.fromList([1, 2, 3, 255, 4, 5, 6, 0])),
      isTrue,
    );
  });

  test('a file that is not png or webp is caught by its content', () async {
    final jpegLike = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0, 0, 0, 0, 0]);
    final f = await inspectImage(jpegLike);
    expect(f.format, isNull);
    expect(f.bytes, 8);
  });
}
