import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Where an uploaded file lives: what Cloudinary returned is the source of
/// truth (CLAUDE.md 3.1), never a guessed URL.
class UploadedFile {
  const UploadedFile({required this.publicId, required this.secureUrl});
  final String publicId;
  final String secureUrl;
}

/// Uploads through the project's unsigned preset `menova` (CLAUDE.md 3.1):
/// no secret in the client. Overwrite is off in the preset, so every upload
/// is a new file and the old one stays for rollback.
class CloudinaryUploader {
  CloudinaryUploader({http.Client? client}) : _client = client ?? http.Client();

  static const cloudName = 'etdgj6d8';
  static const preset = 'menova';
  static const folder = 'menova/assets';

  final http.Client _client;

  Future<UploadedFile> upload(Uint8List bytes, String filename) async {
    final req =
        http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
            ),
          )
          ..fields['upload_preset'] = preset
          ..fields['folder'] = folder
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );
    final res = await http.Response.fromStream(await _client.send(req));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw StateError('Cloudinary ${res.statusCode}: ${body['error']}');
    }
    return UploadedFile(
      publicId: body['public_id'] as String,
      secureUrl: body['secure_url'] as String,
    );
  }
}
