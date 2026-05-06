import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../config/cloudinary_config.dart';

class CloudinaryService {
  Future<String> uploadImage({
    required Uint8List bytes,
    required String fileName,
    required String folder,
  }) async {
    if (!CloudinaryConfig.isConfigured) {
      throw Exception(
        '${CloudinaryConfig.setupMessage} Example: '
        '${CloudinaryConfig.exampleRunCommand()}',
      );
    }

    final uri = Uri.parse(
      'https://api.cloudinary.com/v1_1/${CloudinaryConfig.cloudName}/upload',
    );
    final request = http.MultipartRequest('POST', uri)
      ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
      ..fields['folder'] = _normalizeFolder(folder)
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName.trim().isEmpty ? 'upload.jpg' : fileName.trim(),
        ),
      );

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception(
        'Upload timed out. Please check your internet connection.',
      ),
    );
    final response = await http.Response.fromStream(streamedResponse);
    final payload = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message =
          (payload['error'] as Map<String, dynamic>?)?['message']?.toString() ??
          'Upload failed with status ${response.statusCode}.';
      throw Exception(message);
    }

    final secureUrl = (payload['secure_url'] ?? '').toString().trim();
    if (secureUrl.isEmpty) {
      throw Exception('Cloudinary did not return a secure image URL.');
    }

    return secureUrl;
  }

  String _normalizeFolder(String folder) {
    final cleanedFolder = folder.trim().replaceAll('\\', '/');
    if (cleanedFolder.isEmpty) {
      return CloudinaryConfig.uploadFolder;
    }
    return '${CloudinaryConfig.uploadFolder}/$cleanedFolder';
  }
}
