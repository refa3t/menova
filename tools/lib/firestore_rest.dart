// Firestore REST writes as the logged-in Firebase CLI user (IAM owner):
// no service-account key on disk, security rules stay locked for clients.
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Only the staging project may receive TEMP data (no production project
/// exists yet; OWNER_INPUTS decision 10).
const stagingProjectId = 'menova-80602';

/// Access token of the logged-in Firebase CLI user. Exits on failure.
Future<String> firebaseToken() async {
  final token = await Process.run('node', ['firebase_token.js']);
  if (token.exitCode != 0) {
    stderr.writeln('Could not get token: ${token.stderr}');
    exit(1);
  }
  return '${token.stdout}'.trim();
}

Future<void> batchWrite(
  String projectId,
  String token,
  Map<String, Map<String, Object?>> docs,
) async {
  final root = 'projects/$projectId/databases/(default)/documents';
  final entries = docs.entries.toList();
  // batchWrite accepts up to 500 writes per call.
  for (var i = 0; i < entries.length; i += 500) {
    final chunk = entries.skip(i).take(500);
    final res = await http.post(
      Uri.parse('https://firestore.googleapis.com/v1/$root:batchWrite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'writes': [
          for (final e in chunk)
            {
              'update': {
                'name': '$root/${e.key}',
                'fields': {
                  for (final f in e.value.entries)
                    f.key: firestoreValue(f.value),
                },
              },
            },
        ],
      }),
    );
    if (res.statusCode != 200) {
      stderr.writeln('Firestore error ${res.statusCode}: ${res.body}');
      exit(1);
    }
    final statuses = (jsonDecode(res.body)['status'] as List?) ?? const [];
    final failed = statuses.where((s) => (s as Map)['code'] != null).length;
    if (failed > 0) {
      stderr.writeln('$failed writes failed: ${res.body}');
      exit(1);
    }
  }
  print('${docs.length} documents written to $projectId');
}

/// Encodes a JSON value as a Firestore REST `Value`.
Map<String, Object?> firestoreValue(Object? v) => switch (v) {
  null => {'nullValue': null},
  bool b => {'booleanValue': b},
  int n => {'integerValue': '$n'},
  double d => {'doubleValue': d},
  String s => {'stringValue': s},
  List l => {
    'arrayValue': {'values': l.map(firestoreValue).toList()},
  },
  Map m => {
    'mapValue': {
      'fields': {
        for (final e in m.entries) '${e.key}': firestoreValue(e.value),
      },
    },
  },
  _ => throw ArgumentError('Unsupported value: $v'),
};

/// Ids of documents in [collection] edited from the admin panel (they carry
/// `lastAuditId`): from then on the admin owns their content.
Future<Set<String>> adminEditedIds(
  String projectId,
  String token,
  String collection,
) async {
  final ids = <String>{};
  String? page;
  do {
    final uri = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/'
      '(default)/documents/$collection?pageSize=300'
      '&mask.fieldPaths=lastAuditId${page == null ? '' : '&pageToken=$page'}',
    );
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) {
      stderr.writeln('Firestore error ${res.statusCode}: ${res.body}');
      exit(1);
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    for (final d in (body['documents'] as List?) ?? const []) {
      final doc = d as Map<String, dynamic>;
      if ((doc['fields'] as Map?)?.containsKey('lastAuditId') ?? false) {
        ids.add((doc['name'] as String).split('/').last);
      }
    }
    page = body['nextPageToken'] as String?;
  } while (page != null);
  return ids;
}
