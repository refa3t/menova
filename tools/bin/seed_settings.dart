// Writes the store settings document (`settings/store`): location and
// delivery rules. Validated with the core model first. The admin panel will
// edit this document later (phase 3).
//
// Usage (from tools/):
//   dart run bin/seed_settings.dart [--file seed/store_settings.json] [--dry-run]
import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:menova_tools/firestore_rest.dart';

Future<void> main(List<String> args) async {
  final i = args.indexOf('--file');
  final path = i >= 0 && i + 1 < args.length
      ? args[i + 1]
      : 'seed/store_settings.json';
  final raw = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>
    ..remove('_note');
  final settings = StoreSettings.fromJson(raw);
  print(
    'settings/store validated${settings.temp ? ' (TEMP data, staging only)' : ''}: '
    '${settings.location}, ${settings.delivery.toJson()}',
  );
  if (args.contains('--dry-run')) return;
  await batchWrite(stagingProjectId, await firebaseToken(), {
    'settings/store': settings.toJson(),
  });
}
