import 'image_picker.dart';

/// Non-web builds (tests): nothing to pick.
Future<List<PickedImage>> pickImages({bool multiple = false}) async => const [];
