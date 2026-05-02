import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase/supabase.dart';

const _defaultFirebaseBucket = 'shopingapp-26662.firebasestorage.app';
const _defaultOutput = 'firebase_storage_map.json';
const _firebaseStorageOrigin = 'firebasestorage.googleapis.com';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');
  final firebaseBucket = options['firebase-bucket'] ?? _defaultFirebaseBucket;
  final outputPath = options['output'] ?? _defaultOutput;
  final limit = int.tryParse(options['limit'] ?? '');

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
      r'dart run tool/migrate_firebase_storage_to_supabase.dart --dry-run',
    );
    exitCode = 64;
    return;
  }

  final firebaseAccessToken = await _loadFirebaseAccessToken();
  if (firebaseAccessToken == null || firebaseAccessToken.isEmpty) {
    stderr.writeln(
      'Missing Firebase access token.\n'
      'Run `npx -y firebase-tools login` on this machine first, or set '
      '`FIREBASE_STORAGE_ACCESS_TOKEN` in the environment.',
    );
    exitCode = 64;
    return;
  }

  final client = SupabaseClient(url, serviceRoleKey);
  final httpClient = HttpClient();
  final mappings = <Map<String, dynamic>>[];
  var migrated = 0;
  var skipped = 0;
  var failed = 0;
  var scanned = 0;
  var lastProgressLog = 0;

  stdout.writeln(
    'Scanning Firebase Storage bucket $firebaseBucket. '
    'Mode: ${dryRun ? 'dry-run' : 'write'}',
  );

  try {
    final objectNames = await _listFirebaseObjects(
      httpClient,
      bucket: firebaseBucket,
      accessToken: firebaseAccessToken,
      limit: limit,
    );

    stdout.writeln('Found ${objectNames.length} Firebase Storage object(s).');

    for (final objectName in objectNames) {
      scanned++;
      final pathMapping = _mapObject(objectName);
      if (pathMapping == null) {
        skipped++;
        stderr.writeln('SKIP unsupported path: $objectName');
        continue;
      }

      try {
        final canonicalFirebaseUrl = _buildFirebaseMediaUrl(
          bucket: firebaseBucket,
          objectName: objectName,
        );
        final contentType = _guessContentType(objectName);
        final resolvedValue = pathMapping.isPrivate
            ? pathMapping.targetPath
            : client.storage
                .from(pathMapping.targetBucket)
                .getPublicUrl(pathMapping.targetPath);

        if (!dryRun) {
          final bytes = await _downloadFirebaseObject(
            httpClient,
            bucket: firebaseBucket,
            objectName: objectName,
            accessToken: firebaseAccessToken,
          );

          await client.storage.from(pathMapping.targetBucket).uploadBinary(
            pathMapping.targetPath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              cacheControl: '3600',
              contentType: contentType,
            ),
          );
        }

        mappings.add({
          'sourceBucket': firebaseBucket,
          'sourceObject': objectName,
          'sourceFirebaseUrl': canonicalFirebaseUrl,
          'targetBucket': pathMapping.targetBucket,
          'targetPath': pathMapping.targetPath,
          'resolvedValue': resolvedValue,
          'isPrivate': pathMapping.isPrivate,
          'contentType': contentType,
        });

        migrated++;
        if (migrated - lastProgressLog >= 100) {
          lastProgressLog = migrated;
          stdout.writeln(
            'Progress: processed=$scanned migrated=$migrated '
            'skipped=$skipped failed=$failed',
          );
        }
      } catch (error) {
        failed++;
        stderr.writeln('FAIL $objectName :: $error');
      }
    }
  } finally {
    httpClient.close(force: true);
  }

  final outputFile = File(outputPath);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(mappings),
  );

  stdout.writeln(
    'Done. scanned=$scanned migrated=$migrated skipped=$skipped failed=$failed',
  );
  stdout.writeln('Storage map written to ${outputFile.path}');
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

Future<String?> _loadFirebaseAccessToken() async {
  final fromEnv = Platform.environment['FIREBASE_STORAGE_ACCESS_TOKEN'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }

  final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'];
  if (home == null || home.isEmpty) {
    return null;
  }

  final candidates = <String>[
    '$home/.config/configstore/firebase-tools.json',
    '${Platform.environment['APPDATA'] ?? ''}/configstore/firebase-tools.json',
  ];

  for (final candidate in candidates) {
    if (candidate.trim().isEmpty) {
      continue;
    }

    final file = File(candidate);
    if (!file.existsSync()) {
      continue;
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        continue;
      }

      final tokens = decoded['tokens'];
      if (tokens is! Map<String, dynamic>) {
        continue;
      }

      final accessToken = tokens['access_token']?.toString();
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    } catch (_) {
      continue;
    }
  }

  return null;
}

Future<List<String>> _listFirebaseObjects(
  HttpClient client, {
  required String bucket,
  required String accessToken,
  int? limit,
}) async {
  final objects = <String>[];
  String? pageToken;

  while (true) {
    final remaining = limit == null ? 1000 : (limit - objects.length);
    if (remaining <= 0) {
      break;
    }

    final queryParameters = <String, String>{
      'maxResults': '${remaining > 1000 ? 1000 : remaining}',
    };
    if (pageToken != null) {
      queryParameters['pageToken'] = pageToken;
    }
    final uri = Uri.https(
      _firebaseStorageOrigin,
      '/v0/b/$bucket/o',
      queryParameters,
    );
    final response = await _requestJson(
      client,
      uri,
      accessToken: accessToken,
    ) as Map<String, dynamic>;

    final items = response['items'];
    if (items is List) {
      for (final item in items.whereType<Map>()) {
        final name = item['name']?.toString();
        if (name != null && name.isNotEmpty) {
          objects.add(name);
          if (limit != null && objects.length >= limit) {
            return objects;
          }
        }
      }
    }

    pageToken = response['nextPageToken']?.toString();
    if (pageToken == null || pageToken.isEmpty) {
      break;
    }
  }

  return objects;
}

Future<Uint8List> _downloadFirebaseObject(
  HttpClient client, {
  required String bucket,
  required String objectName,
  required String accessToken,
}) async {
  final uri = Uri.https(
    _firebaseStorageOrigin,
    '/v0/b/$bucket/o/${Uri.encodeComponent(objectName)}',
    {'alt': 'media'},
  );
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
  final response = await request.close();
  final bodyBytes = await response.fold<List<int>>(
    <int>[],
    (buffer, chunk) => buffer..addAll(chunk),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Firebase download failed (${response.statusCode}) '
      '${utf8.decode(bodyBytes, allowMalformed: true)}',
      uri: uri,
    );
  }

  return Uint8List.fromList(bodyBytes);
}

Future<dynamic> _requestJson(
  HttpClient client,
  Uri uri, {
  required String accessToken,
}) async {
  final request = await client.getUrl(uri);
  request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $accessToken');
  final response = await request.close();
  final body = await response.transform(utf8.decoder).join();

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw HttpException(
      'Firebase API request failed (${response.statusCode}) $body',
      uri: uri,
    );
  }

  if (body.trim().isEmpty) {
    return const <String, dynamic>{};
  }

  return jsonDecode(body);
}

String _buildFirebaseMediaUrl({
  required String bucket,
  required String objectName,
}) {
  return Uri.https(
    _firebaseStorageOrigin,
    '/v0/b/$bucket/o/${Uri.encodeComponent(objectName)}',
    const {'alt': 'media'},
  ).toString();
}

_PathMapping? _mapObject(String objectName) {
  if (objectName.startsWith('profiles/')) {
    return _PathMapping(
      targetBucket: 'user-profiles',
      targetPath: objectName,
      isPrivate: false,
    );
  }
  if (objectName.startsWith('stores/')) {
    return _PathMapping(
      targetBucket: 'store-media',
      targetPath: objectName,
      isPrivate: false,
    );
  }
  if (objectName.startsWith('products/')) {
    return _PathMapping(
      targetBucket: 'product-media',
      targetPath: objectName,
      isPrivate: false,
    );
  }
  if (objectName.startsWith('chats/')) {
    return _PathMapping(
      targetBucket: 'chat-media',
      targetPath: objectName,
      isPrivate: true,
    );
  }
  return null;
}

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

class _PathMapping {
  const _PathMapping({
    required this.targetBucket,
    required this.targetPath,
    required this.isPrivate,
  });

  final String targetBucket;
  final String targetPath;
  final bool isPrivate;
}
