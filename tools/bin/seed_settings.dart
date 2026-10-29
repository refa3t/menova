// Writes the store settings document (`settings/store`): location and
// delivery rules. Validated with the core model first. The admin panel will
// edit this document later (phase 3).
//
// Usage (from tools/):
//   dart run bin/seed_settings.dart [--file seed/store_settings.json] [--dry-run]
//       [--force]
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
  final token = await firebaseToken();
  // Once the owner edits the settings from the admin panel (P3-05), they
  // own them: keep them unless --force.
  if (!args.contains('--force') &&
      (await adminEditedIds(
        stagingProjectId,
        token,
        'settings',
      )).contains('store')) {
    print('kept admin-edited settings/store (pass --force to overwrite)');
    return;
  }
  await batchWrite(stagingProjectId, token, {
    'settings/store': settings.toJson(),
  });
}
