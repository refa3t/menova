// P0-12: verifies the unsigned `menova` preset restrictions (CLAUDE.md 3.1).
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

const cloudName = 'etdgj6d8';
const preset = 'menova';
const expectedFolder = 'menova/assets';

Future<Map<String, dynamic>> upload(
  Uint8List bytes,
  String filename, {
  Map<String, String> extra = const {},
}) async {
  final req = http.MultipartRequest(
    'POST',
    Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
  )
    ..fields['upload_preset'] = preset
    ..fields.addAll(extra)
    ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
  final res = await http.Response.fromStream(await req.send());
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  return {'status': res.statusCode, ...body};
}

Uint8List smallPng() =>
    img.encodePng(img.Image(width: 8, height: 8, numChannels: 4));

Uint8List jpg() => img.encodeJpg(img.Image(width: 8, height: 8));

/// Random noise PNG so compression cannot shrink it under the limit (~600KB).
Uint8List bigPng() {
  final r = Random(1);
  final im = img.Image(width: 450, height: 450, numChannels: 4);
  for (final p in im) {
    p.setRgba(r.nextInt(256), r.nextInt(256), r.nextInt(256), 255);
  }
  return img.encodePng(im, level: 0);
}

var failures = 0;
void check(String name, bool ok, Object detail) {
  if (!ok) failures++;
  print('${ok ? 'PASS' : 'FAIL'}  $name  ->  $detail');
}

Future<void> main() async {
  final a = await upload(smallPng(), 'probe.png');
  check(
    'PNG accepted, returns secure_url + public_id',
    a['status'] == 200 && a['secure_url'] != null && a['public_id'] != null,
    {'public_id': a['public_id'], 'secure_url': a['secure_url'], 'err': a['error']},
  );
  check(
    'asset_folder is $expectedFolder',
    a['asset_folder'] == expectedFolder,
    a['asset_folder'] ?? 'missing',
  );

  final id = 'probe_${DateTime.now().millisecondsSinceEpoch}';
  final b = await upload(smallPng(), 'probe.png', extra: {'public_id': id});
  print('INFO  client public_id honored? ${b['public_id'] == id} -> ${b['public_id'] ?? b['error']}');

  final c = await upload(smallPng(), 'probe.png', extra: {'folder': 'other'});
  print('INFO  client folder override -> asset_folder=${c['asset_folder']} public_id=${c['public_id'] ?? c['error']}');

  final d = await upload(jpg(), 'probe.jpg');
  check('JPG rejected', d['status'] != 200, d['error'] ?? d['public_id']);

  final big = bigPng();
  final e = await upload(big, 'big.png');
  check('PNG over 500KB (${big.length ~/ 1024}KB) rejected', e['status'] != 200,
      e['error'] ?? e['public_id']);

  print(failures == 0 ? '\nALL CHECKS PASSED' : '\n$failures CHECK(S) FAILED');
}
