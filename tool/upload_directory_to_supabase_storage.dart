import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');
  final dirPath = options['dir'];
  final bucket = options['bucket'];
  final prefix = options['prefix'] ?? '';

  final url = Platform.environment['SUPABASE_URL'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null ||
      url.isEmpty ||
      serviceRoleKey == null ||
      serviceRoleKey.isEmpty) {
    stderr.writeln(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.\n'
      'Example:\n'
      r'$env:SUPABASE_URL="https://your-project.supabase.co"'
      '\n'
      r'$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"'
      '\n'
      r'dart run tool/upload_directory_to_supabase_storage.dart --dir=firebase_storage_export --bucket=product-media',
    );
    exitCode = 64;
    return;
  }

  if (dirPath == null || dirPath.isEmpty || bucket == null || bucket.isEmpty) {
    stderr.writeln(
      'Missing required arguments.\n'
      'Usage:\n'
      'dart run tool/upload_directory_to_supabase_storage.dart '
      '--dir=<local-directory> --bucket=<supabase-bucket> [--prefix=<path>] [--dry-run]',
    );
    exitCode = 64;
    return;
  }

  final root = Directory(dirPath);
  if (!root.existsSync()) {
    stderr.writeln('Directory not found: $dirPath');
    exitCode = 66;
    return;
  }

  final client = SupabaseClient(url, serviceRoleKey);
  final files =
      root
          .listSync(recursive: true)
          .whereType<File>()
          .where((file) => file.existsSync())
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  stdout.writeln(
    'Found ${files.length} files under ${root.path}. '
    'Mode: ${dryRun ? 'dry-run' : 'write'}',
  );

  var uploaded = 0;
  var failed = 0;

  for (final file in files) {
    final relativePath = _toPosix(
      file.path
          .substring(root.path.length)
          .replaceFirst(RegExp(r'^[\\/]+'), ''),
    );
    final destinationPath = _joinPosix(prefix, relativePath);
    final contentType = _guessContentType(file.path);

    try {
      if (dryRun) {
        stdout.writeln('PLAN ${file.path} -> $bucket/$destinationPath');
      } else {
        await client.storage
            .from(bucket)
            .upload(
              destinationPath,
              file,
              fileOptions: FileOptions(
                upsert: true,
                cacheControl: '3600',
                contentType: contentType,
              ),
            );
        stdout.writeln('OK   ${file.path} -> $bucket/$destinationPath');
      }
      uploaded++;
    } catch (error) {
      failed++;
      stderr.writeln('FAIL ${file.path} -> $bucket/$destinationPath :: $error');
    }
  }

  stdout.writeln('Done. uploaded=$uploaded failed=$failed');
}

Map<String, String?> _parseArgs(List<String> args) {
  final options = <String, String?>{};
  for (final arg in args) {
    if (arg == '--dry-run') {
      options['dry-run'] = 'true';
      continue;
    }
    if (!arg.startsWith('--')) {
      continue;
    }
    final index = arg.indexOf('=');
    if (index == -1) {
      options[arg.substring(2)] = 'true';
    } else {
      options[arg.substring(2, index)] = arg.substring(index + 1);
    }
  }
  return options;
}

String _joinPosix(String prefix, String relativePath) {
  final cleanedPrefix = _toPosix(prefix).replaceAll(RegExp(r'^/+|/+$'), '');
  final cleanedRelative = _toPosix(relativePath).replaceAll(RegExp(r'^/+'), '');
  if (cleanedPrefix.isEmpty) {
    return cleanedRelative;
  }
  if (cleanedRelative.isEmpty) {
    return cleanedPrefix;
  }
  return '$cleanedPrefix/$cleanedRelative';
}

String _toPosix(String path) => path.replaceAll('\\', '/');

String _guessContentType(String path) {
  final lower = path.toLowerCase();
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
    return 'image/jpeg';
  }
  if (lower.endsWith('.png')) {
    return 'image/png';
  }
  if (lower.endsWith('.webp')) {
    return 'image/webp';
  }
  if (lower.endsWith('.gif')) {
    return 'image/gif';
  }
  if (lower.endsWith('.svg')) {
    return 'image/svg+xml';
  }
  if (lower.endsWith('.json')) {
    return 'application/json';
  }
  if (lower.endsWith('.mp4')) {
    return 'video/mp4';
  }
  return 'application/octet-stream';
}
