// Uploads processed assets under assets_src/<category>/ to Cloudinary via the
// unsigned `menova` preset and records what Cloudinary returned (the source of
// truth, CLAUDE.md 3.1) in assets_src/<category>/cloudinary_manifest.json.
// Idempotent: files already in the manifest are skipped.
//
// Usage (from tools/): dart run bin/upload_assets.dart pizza
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const cloudName = 'etdgj6d8';
const preset = 'menova';
const folder = 'menova/assets';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln('usage: dart run bin/upload_assets.dart <category>');
    exit(64);
  }
  final root = Directory('../assets_src/${args.single}');
  final manifestFile = File('${root.path}/cloudinary_manifest.json');
  final manifest = manifestFile.existsSync()
      ? (jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>)
      : <String, dynamic>{};

  final files = root
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.webp') || f.path.endsWith('.png'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var uploaded = 0;
  for (final f in files) {
    final name = f.uri.pathSegments.last;
    if (manifest.containsKey(name)) continue;
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
    )
      ..fields['upload_preset'] = preset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', f.path));
    final res = await http.Response.fromStream(await req.send());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      stderr.writeln('FAIL $name: ${body['error']}');
      exitCode = 1;
      break;
    }
    manifest[name] = {
      'publicId': body['public_id'],
      'secureUrl': body['secure_url'],
      'version': body['version'],
      'bytes': body['bytes'],
    };
    // Save after each upload so a failure never loses recorded results.
    manifestFile.writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(manifest));
    uploaded++;
    print('OK   $name -> ${body['secure_url']}');
  }
  print('$uploaded uploaded, ${manifest.length} in manifest');
}
