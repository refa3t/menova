// Grants a staff role (custom claim `role`) to an existing Firebase Auth
// user, as the logged-in Firebase CLI owner. Roles: reception, kitchen (reception app), owner, menu_manager (admin).
// Pass `none` to remove the role. The user must sign in again (or wait for
// the token to refresh) for it to apply.
//
// Usage (from tools/): dart run bin/set_staff_role.dart <email> <role|none>
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const projectId = 'menova-80602';
const roles = {'reception', 'kitchen', 'owner', 'menu_manager', 'none'};

Future<void> main(List<String> args) async {
  if (args.length != 2 || !roles.contains(args[1])) {
    stderr.writeln(
      'usage: dart run bin/set_staff_role.dart <email> <reception|kitchen|owner|menu_manager|none>',
    );
    exit(64);
  }
  final token = await Process.run('node', ['firebase_token.js']);
  if (token.exitCode != 0) {
    stderr.writeln('Could not get token: ${token.stderr}');
    exit(1);
  }
  final headers = {
    'Authorization': 'Bearer ${'${token.stdout}'.trim()}',
    'Content-Type': 'application/json',
    'x-goog-user-project': projectId,
  };
  const base = 'https://identitytoolkit.googleapis.com/v1/projects/$projectId';

  final lookup = await http.post(
    Uri.parse('$base/accounts:lookup'),
    headers: headers,
    body: jsonEncode({
      'email': [args[0]],
    }),
  );
  final users = (jsonDecode(lookup.body)['users'] as List?) ?? const [];
  if (lookup.statusCode != 200 || users.isEmpty) {
    stderr.writeln(
      'No user with email ${args[0]} (${lookup.statusCode}). '
      'Create the account in Firebase Console > Authentication first.',
    );
    exit(1);
  }
  final uid = users.first['localId'] as String;
  final claims = args[1] == 'none' ? <String, Object>{} : {'role': args[1]};
  final update = await http.post(
    Uri.parse('$base/accounts:update'),
    headers: headers,
    body: jsonEncode({'localId': uid, 'customAttributes': jsonEncode(claims)}),
  );
  if (update.statusCode != 200) {
    stderr.writeln('Update failed ${update.statusCode}: ${update.body}');
    exit(1);
  }
  print('${args[0]} -> ${args[1]}');
}
