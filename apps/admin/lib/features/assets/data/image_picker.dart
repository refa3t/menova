import 'dart:typed_data';

import 'image_picker_stub.dart'
    if (dart.library.js_interop) 'image_picker_web.dart'
    as impl;

/// A file the admin picked from their device.
class PickedImage {
  const PickedImage({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

/// Opens the browser's file picker for images; empty when cancelled.
Future<List<PickedImage>> pickImages({bool multiple = false}) =>
    impl.pickImages(multiple: multiple);
