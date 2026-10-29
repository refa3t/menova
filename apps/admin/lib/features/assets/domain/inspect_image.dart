import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:category_definitions/category_definitions.dart';

/// Reads a picked file's real format (first bytes), size and whether any
/// pixel is see-through, for `validateAssetFile` (P3-04).
Future<AssetFile> inspectImage(Uint8List bytes) async {
  final format = AssetFile.sniff(bytes.take(16).toList());
  var alpha = false;
  if (format != null) {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData();
      if (data != null) alpha = hasTransparentPixel(data.buffer.asUint8List());
      frame.image.dispose();
    } on Object {
      alpha = false;
    }
  }
  return AssetFile(format: format, bytes: bytes.length, hasTransparency: alpha);
}

/// True when any pixel of raw RGBA [rgba] is not fully opaque.
bool hasTransparentPixel(Uint8List rgba) {
  for (var i = 3; i < rgba.length; i += 4) {
    if (rgba[i] < 255) return true;
  }
  return false;
}
