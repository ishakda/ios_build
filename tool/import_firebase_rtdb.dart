import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

const _defaultInput = 'firebase_rtdb_export.json';
const _defaultUidMap = 'firebase_uid_map.json';
const _defaultStorageMap = 'firebase_storage_map.json';
const _uuid = Uuid();

const _knownTables = <String>[
  'users',
  'products',
  'reviews',
  'chats',
  'messages',
  'orders',
  'notifications',
  'addresses',
  'paymentMethods',
  'storeFollowers',
];

const _uuidIdTables = <String>{
  'messages',
  'notifications',
  'addresses',
  'paymentMethods',
  'storeFollowers',
};

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');
  final inputPath = options['input'] ?? _defaultInput;
  final uidMapPath = options['uid-map'] ?? _defaultUidMap;
  final storageMapPath = options['storage-map'] ?? _defaultStorageMap;

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
      r'dart run tool/import_firebase_rtdb.dart --input=firebase_rtdb_export.json',
    );
    exitCode = 64;
    return;
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Firebase RTDB export not found: $inputPath');
    exitCode = 66;
    return;
  }

  final uidMap = File(uidMapPath).existsSync()
      ? _loadUidMap(await File(uidMapPath).readAsString())
      : <String, String>{};
  final storageMap = File(storageMapPath).existsSync()
      ? _loadStorageMap(await File(storageMapPath).readAsString())
      : <String, String>{};
  final root =
      jsonDecode(await inputFile.readAsString()) as Map<String, dynamic>;
  final client = SupabaseClient(url, serviceRoleKey);

  var imported = 0;
  var skipped = 0;
  var failed = 0;

  for (final table in _knownTables) {
    final rawCollection = root[table];
    if (rawCollection == null) {
      continue;
    }

    final rows = _normalizeCollection(rawCollection, table);
    stdout.writeln('Table $table: ${rows.length} rows');

    for (final row in rows) {
      try {
        final normalized = _normalizeRow(
          table,
          row,
          uidMap: uidMap,
          storageMap: storageMap,
        );

        if (normalized == null) {
          skipped++;
          continue;
        }

        if (dryRun) {
          imported++;
          continue;
        }

        await client.from(table).upsert(normalized);
        imported++;
      } catch (error) {
        failed++;
        stderr.writeln('FAIL [$table] ${row['id'] ?? '-'} $error');
      }
    }
  }

  stdout.writeln(
    'Done. imported=$imported skipped=$skipped failed=$failed '
    '(uidMapEntries=${uidMap.length}, storageMapEntries=${storageMap.length})',
  );
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

Map<String, String> _loadUidMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return const {};
  }

  final map = <String, String>{};
  for (final item in decoded.whereType<Map>()) {
    final firebaseUid = item['firebaseUid']?.toString();
    final supabaseUserId = item['supabaseUserId']?.toString();
    if (firebaseUid != null &&
        firebaseUid.isNotEmpty &&
        supabaseUserId != null &&
        supabaseUserId.isNotEmpty) {
      map[firebaseUid] = supabaseUserId;
    }
  }
  return map;
}

Map<String, String> _loadStorageMap(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) {
    return const {};
  }

  final map = <String, String>{};
  for (final item in decoded.whereType<Map>()) {
    final sourceFirebaseUrl = item['sourceFirebaseUrl']?.toString();
    final sourceObject = item['sourceObject']?.toString();
    final resolvedValue = item['resolvedValue']?.toString();
    if (sourceFirebaseUrl != null &&
        sourceFirebaseUrl.isNotEmpty &&
        resolvedValue != null &&
        resolvedValue.isNotEmpty) {
      map[sourceFirebaseUrl] = resolvedValue;
    }
    if (sourceObject != null &&
        sourceObject.isNotEmpty &&
        resolvedValue != null &&
        resolvedValue.isNotEmpty) {
      map[sourceObject] = resolvedValue;
    }
  }
  return map;
}

List<Map<String, dynamic>> _normalizeCollection(Object raw, String table) {
  if (raw is List) {
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  if (raw is Map) {
    return raw.entries.where((entry) => entry.value is Map).map((entry) {
      final map = Map<String, dynamic>.from(entry.value as Map);
      map.putIfAbsent('id', () => entry.key.toString());
      return map;
    }).toList();
  }

  stderr.writeln('SKIP table $table unsupported collection format');
  return const [];
}

Map<String, dynamic>? _normalizeRow(
  String table,
  Map<String, dynamic> row, {
  required Map<String, String> uidMap,
  required Map<String, String> storageMap,
}) {
  final normalized = Map<String, dynamic>.from(row);

  final rawId = normalized['id']?.toString();
  if (rawId == null || rawId.isEmpty) {
    normalized['id'] = _uuid.v4();
  } else if (_uuidIdTables.contains(table) && !_isUuid(rawId)) {
    normalized['id'] = _uuid.v5(Namespace.url.value, '$table:$rawId');
  }

  switch (table) {
    case 'users':
      normalized['id'] = _mapUserId(normalized['id'], uidMap);
      normalized['followingStores'] = _mapUserIdList(
        normalized['followingStores'],
        uidMap,
      );
      normalized['profileImageUrl'] = _rewriteAssetUrl(
        normalized['profileImageUrl'],
        storageMap,
      );
      normalized['coverImageUrl'] = _rewriteAssetUrl(
        normalized['coverImageUrl'],
        storageMap,
      );
      normalized['storeLogo'] = _rewriteAssetUrl(
        normalized['storeLogo'],
        storageMap,
      );
      _normalizeTimestamps(normalized, const ['createdAt', 'updatedAt']);
      break;
    case 'products':
      normalized['sellerId'] = _mapUserId(normalized['sellerId'], uidMap);
      normalized['imageUrl'] = _rewriteAssetUrl(
        normalized['imageUrl'],
        storageMap,
      );
      normalized['images'] = _rewriteAssetUrlList(
        normalized['images'],
        storageMap,
      );
      normalized['detailImageUrls'] = _rewriteAssetUrlList(
        normalized['detailImageUrls'],
        storageMap,
      );
      break;
    case 'reviews':
      normalized['userId'] = _mapUserId(normalized['userId'], uidMap);
      normalized['userImageUrl'] = _rewriteAssetUrl(
        normalized['userImageUrl'],
        storageMap,
      );
      _normalizeTimestamps(normalized, const ['createdAt']);
      break;
    case 'chats':
      normalized['id'] = _canonicalChatId(normalized['id'], uidMap);
      normalized['participants'] = _mapUserIdList(
        normalized['participants'],
        uidMap,
      );
      normalized['lastMessage'] = _normalizeText(normalized['lastMessage']);
      _normalizeTimestamps(normalized, const ['lastTimestamp']);
      break;
    case 'messages':
      normalized['chatId'] = _canonicalChatId(normalized['chatId'], uidMap);
      normalized['senderId'] = _mapUserId(normalized['senderId'], uidMap);
      normalized['receiverId'] = _mapUserId(normalized['receiverId'], uidMap);
      normalized['text'] = _normalizeText(normalized['text']);
      normalized['imageUrl'] = _rewriteAssetUrl(
        normalized['imageUrl'],
        storageMap,
      );
      _normalizeTimestamps(normalized, const ['timestamp']);
      break;
    case 'orders':
      normalized['buyerId'] = _mapUserId(normalized['buyerId'], uidMap);
      normalized['sellerIds'] = _mapUserIdList(normalized['sellerIds'], uidMap);
      _rewriteOrderItems(normalized, uidMap);
      _normalizeTimestamps(normalized, const ['orderDate']);
      break;
    case 'notifications':
      normalized['userId'] = _mapUserId(normalized['userId'], uidMap);
      _normalizeTimestamps(normalized, const ['timestamp']);
      break;
    case 'addresses':
      normalized['userId'] = _mapUserId(normalized['userId'], uidMap);
      _normalizeTimestamps(normalized, const ['updatedAt']);
      break;
    case 'paymentMethods':
      normalized['userId'] = _mapUserId(normalized['userId'], uidMap);
      _normalizeTimestamps(normalized, const ['createdAt']);
      break;
    case 'storeFollowers':
      normalized['userId'] = _mapUserId(normalized['userId'], uidMap);
      normalized['vendorId'] = _mapUserId(normalized['vendorId'], uidMap);
      _normalizeTimestamps(normalized, const ['createdAt']);
      break;
  }

  return normalized;
}

String? _canonicalChatId(Object? value, Map<String, String> uidMap) {
  final raw = value?.toString().trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }

  if (!raw.contains('_')) {
    return raw;
  }

  final ids =
      raw
          .split('_')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .map((part) => uidMap[part] ?? part)
          .toList()
        ..sort();

  if (ids.length != 2) {
    return raw;
  }

  return ids.join('_');
}

String _normalizeText(Object? value) {
  final raw = value?.toString() ?? '';
  if (raw.isEmpty) return raw;
  final hasMojibakeMarkers =
      raw.contains('Ã') ||
      raw.contains('â') ||
      raw.contains('ð') ||
      raw.contains('�');
  if (!hasMojibakeMarkers) {
    return raw;
  }

  try {
    return utf8.decode(latin1.encode(raw), allowMalformed: true);
  } catch (_) {
    return raw;
  }
}

String? _rewriteAssetUrl(Object? value, Map<String, String> storageMap) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return raw;
  }
  final direct = storageMap[raw];
  if (direct != null && direct.isNotEmpty) {
    return direct;
  }

  final objectPath = _extractFirebaseObjectPath(raw);
  if (objectPath != null && objectPath.isNotEmpty) {
    final mapped = storageMap[objectPath];
    if (mapped != null && mapped.isNotEmpty) {
      return mapped;
    }
  }

  return raw;
}

List<String> _rewriteAssetUrlList(
  Object? value,
  Map<String, String> storageMap,
) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => _rewriteAssetUrl(item, storageMap) ?? '')
      .where((item) => item.isNotEmpty)
      .toList();
}

String? _extractFirebaseObjectPath(String raw) {
  final uri = Uri.tryParse(raw);
  if (uri == null) {
    return null;
  }
  if (!uri.host.contains('firebasestorage.googleapis.com')) {
    return null;
  }

  final segments = uri.pathSegments;
  final objectIndex = segments.indexOf('o');
  if (objectIndex == -1 || objectIndex + 1 >= segments.length) {
    return null;
  }

  final encoded = segments.sublist(objectIndex + 1).join('/');
  return Uri.decodeComponent(encoded);
}

String? _mapUserId(Object? value, Map<String, String> uidMap) {
  final id = value?.toString();
  if (id == null || id.isEmpty) {
    return null;
  }
  return uidMap[id] ?? id;
}

List<String> _mapUserIdList(Object? value, Map<String, String> uidMap) {
  if (value is! List) {
    return const [];
  }
  return value
      .map((item) => _mapUserId(item, uidMap))
      .whereType<String>()
      .toSet()
      .toList();
}

void _rewriteOrderItems(Map<String, dynamic> row, Map<String, String> uidMap) {
  final items = row['items'];
  if (items is! List) {
    return;
  }

  row['items'] = items.map((item) {
    if (item is! Map) {
      return item;
    }
    final normalizedItem = Map<String, dynamic>.from(item);
    final product = normalizedItem['product'];
    if (product is Map) {
      final normalizedProduct = Map<String, dynamic>.from(product);
      normalizedProduct['sellerId'] = _mapUserId(
        normalizedProduct['sellerId'],
        uidMap,
      );
      normalizedItem['product'] = normalizedProduct;
    }
    return normalizedItem;
  }).toList();
}

void _normalizeTimestamps(Map<String, dynamic> row, List<String> keys) {
  for (final key in keys) {
    final value = row[key];
    final parsed = _parseTimestamp(value);
    if (parsed != null) {
      row[key] = parsed.toUtc().toIso8601String();
    }
  }
}

DateTime? _parseTimestamp(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }
  if (value is double) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }
  final text = value.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  final number = int.tryParse(text);
  if (number != null) {
    return DateTime.fromMillisecondsSinceEpoch(number, isUtc: true);
  }
  return DateTime.tryParse(text)?.toUtc();
}

bool _isUuid(String value) {
  final pattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
  );
  return pattern.hasMatch(value);
}
