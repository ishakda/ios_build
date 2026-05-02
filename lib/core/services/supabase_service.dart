import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  const SupabaseService._();

  static const int maxImageUploadBytes = 5 * 1024 * 1024;
  static const Set<String> _allowedImageExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };

  static SupabaseClient get client => Supabase.instance.client;

  static String? get currentUserId => client.auth.currentUser?.id;

  static DateTime parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) {
      return fallback ?? DateTime.now();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(value.toString()) ?? fallback ?? DateTime.now();
  }

  static Future<String> uploadPublicFile({
    required String bucket,
    required String path,
    required File file,
    String contentType = 'application/octet-stream',
    bool upsert = true,
  }) async {
    _assertSafeImageUpload(file: file, path: path, contentType: contentType);

    await client.storage
        .from(bucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            cacheControl: '3600',
            contentType: contentType,
            upsert: upsert,
          ),
        );

    return client.storage.from(bucket).getPublicUrl(path);
  }

  static void _assertSafeImageUpload({
    required File file,
    required String path,
    required String contentType,
  }) {
    if (!file.existsSync()) {
      throw Exception('Selected file no longer exists.');
    }

    if (!contentType.toLowerCase().startsWith('image/')) {
      throw Exception('Only image uploads are allowed.');
    }

    final extension = _extractExtension(path);
    if (!_allowedImageExtensions.contains(extension)) {
      throw Exception('Only JPG, PNG, and WEBP images are allowed.');
    }

    final size = file.lengthSync();
    if (size > maxImageUploadBytes) {
      throw Exception('Image size must be 5 MB or less.');
    }
  }

  static String _extractExtension(String path) {
    final normalized = path.toLowerCase().replaceAll('\\', '/');
    final dotIndex = normalized.lastIndexOf('.');
    if (dotIndex == -1) {
      return '';
    }
    return normalized.substring(dotIndex);
  }
}
