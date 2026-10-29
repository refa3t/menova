import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'image_picker.dart';

Future<List<PickedImage>> pickImages({bool multiple = false}) {
  final done = Completer<List<PickedImage>>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = 'image/png,image/webp'
    ..multiple = multiple;
  Future<void> read() async {
    final files = input.files;
    final picked = <PickedImage>[];
    for (var i = 0; i < (files?.length ?? 0); i++) {
      final f = files!.item(i)!;
      final buffer = await f.arrayBuffer().toDart;
      picked.add(PickedImage(name: f.name, bytes: buffer.toDart.asUint8List()));
    }
    if (!done.isCompleted) done.complete(picked);
  }

  // JS callbacks must not return a Future: start the async read from a
  // plain callback.
  input.onchange = ((web.Event _) {
    read();
  }).toJS;
  input.oncancel = ((web.Event _) {
    if (!done.isCompleted) done.complete(const []);
  }).toJS;
  input.click();
  return done.future;
}
