import 'dart:convert';
import 'dart:io';

const _defaultProject = 'shopingapp-26662';
const _defaultOutput = 'firebase_firestore_export.json';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final apiKey = options['api-key'] ?? Platform.environment['FIREBASE_WEB_API_KEY'];
  final projectId = options['project'] ?? _defaultProject;
  final outputPath = options['output'] ?? _defaultOutput;

  if (apiKey == null || apiKey.isEmpty) {
    stderr.writeln(
      'Missing Firebase Web API key.\n'
      'Use --api-key=<value> or set FIREBASE_WEB_API_KEY.',
    );
    exitCode = 64;
    return;
  }

  final usersDocs = await _queryCollectionGroup(
    apiKey: apiKey,
    projectId: projectId,
    collectionId: 'users',
  );
  final productsDocs = await _queryCollectionGroup(
    apiKey: apiKey,
    projectId: projectId,
    collectionId: 'products',
  );
  final chatsDocs = await _queryCollectionGroup(
    apiKey: apiKey,
    projectId: projectId,
    collectionId: 'chats',
  );
  final messagesDocs = await _queryCollectionGroup(
    apiKey: apiKey,
    projectId: projectId,
    collectionId: 'messages',
  );

  final users = usersDocs.map(_toUserRow).toList();
  final products = productsDocs.map(_toProductRow).toList();
  final chats = chatsDocs.map(_toChatRow).toList();
  final messages = messagesDocs.map(_toMessageRow).toList();

  final payload = <String, dynamic>{
    'users': users,
    'products': products,
    'chats': chats,
    'messages': messages,
  };

  final file = File(outputPath);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));

  stdout.writeln(
    'Exported Firestore collections: '
    'users=${users.length}, products=${products.length}, '
    'chats=${chats.length}, messages=${messages.length}',
  );
  stdout.writeln('Wrote $outputPath');
}

Map<String, String?> _parseArgs(List<String> args) {
  final options = <String, String?>{};
  for (final arg in args) {
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

Future<List<Map<String, dynamic>>> _queryCollectionGroup({
  required String apiKey,
  required String projectId,
  required String collectionId,
}) async {
  final uri = Uri.parse(
    'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey',
  );

  final body = jsonEncode({
    'structuredQuery': {
      'from': [
        {'collectionId': collectionId, 'allDescendants': true},
      ],
      'limit': 500,
    },
  });

  final client = HttpClient();
  try {
    final request = await client.postUrl(uri);
    request.headers.contentType = ContentType.json;
    request.write(body);
    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Firestore query failed ($collectionId): '
        '${response.statusCode} $text',
      );
    }

    final decoded = jsonDecode(text);
    if (decoded is! List) {
      return const [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((row) => row['document'] is Map)
        .map((row) => Map<String, dynamic>.from(row['document'] as Map))
        .toList();
  } finally {
    client.close(force: true);
  }
}

Map<String, dynamic> _toUserRow(Map<String, dynamic> doc) {
  final fields = _decodeFields(doc['fields']);
  final docId = _docId(doc['name']?.toString() ?? '');

  return {
    'id': (fields['id']?.toString().isNotEmpty ?? false)
        ? fields['id']
        : docId,
    'name': fields['name'] ?? '',
    'email': fields['email'] ?? '',
    'profileImageUrl': fields['profileImageUrl'],
    'phoneNumber': fields['phoneNumber'],
    'role': fields['role'] ?? 'buyer',
    'storeName': fields['storeName'],
    'storeDescription': fields['storeDescription'],
    'coverImageUrl': fields['coverImageUrl'],
    'storeLogo': fields['storeLogo'],
    'followerCount': fields['followerCount'] ?? 0,
    'followingStores': fields['followingStores'] ?? const <String>[],
    'fcmToken': fields['fcmToken'],
    'createdAt': fields['createdAt'] ?? doc['createTime'],
    'updatedAt': fields['updatedAt'] ?? doc['updateTime'],
  };
}

Map<String, dynamic> _toProductRow(Map<String, dynamic> doc) {
  final fields = _decodeFields(doc['fields']);
  final docId = _docId(doc['name']?.toString() ?? '');

  return {
    'id': (fields['id']?.toString().isNotEmpty ?? false)
        ? fields['id']
        : docId,
    'name': fields['name'] ?? '',
    'description': fields['description'] ?? '',
    'price': fields['price'] ?? 0,
    'discountPrice': fields['discountPrice'],
    'imageUrl': fields['imageUrl'] ?? '',
    'images': fields['images'] ?? const <String>[],
    'rating': fields['rating'] ?? 0,
    'reviewsCount': fields['reviewsCount'] ?? 0,
    'category': fields['category'] ?? '',
    'isFlashDeal': fields['isFlashDeal'] ?? false,
    'stock': fields['stock'] ?? 0,
    'sellerId': fields['sellerId'],
    'availableColors': fields['availableColors'] ?? const <String>[],
    'availableSizes': fields['availableSizes'] ?? const <String>[],
    'detailImageUrls': fields['detailImageUrls'] ?? const <String>[],
  };
}

Map<String, dynamic> _toChatRow(Map<String, dynamic> doc) {
  final fields = _decodeFields(doc['fields']);
  final docId = _docId(doc['name']?.toString() ?? '');

  return {
    'id': docId,
    'lastMessage': fields['lastMessage'] ?? '',
    'lastTimestamp': fields['lastTimestamp'] ?? doc['updateTime'],
    'participants': fields['participants'] ?? const <String>[],
  };
}

Map<String, dynamic> _toMessageRow(Map<String, dynamic> doc) {
  final fields = _decodeFields(doc['fields']);
  final path = doc['name']?.toString() ?? '';
  final docId = _docId(path);
  final segments = path.split('/');
  final chatIndex = segments.indexOf('chats');
  final chatId = chatIndex != -1 && chatIndex + 1 < segments.length
      ? segments[chatIndex + 1]
      : fields['chatId']?.toString();

  return {
    'id': docId,
    'chatId': chatId,
    'senderId': fields['senderId'],
    'receiverId': fields['receiverId'],
    'text': fields['text'] ?? '',
    'imageUrl': fields['imageUrl'] ?? fields['chatImageUrl'],
    'timestamp': fields['timestamp'] ?? doc['createTime'],
    'isRead': fields['isRead'] ?? false,
  };
}

Map<String, dynamic> _decodeFields(Object? rawFields) {
  if (rawFields is! Map) {
    return const {};
  }
  final map = <String, dynamic>{};
  for (final entry in rawFields.entries) {
    map[entry.key.toString()] = _decodeValue(
      Map<String, dynamic>.from(entry.value as Map),
    );
  }
  return map;
}

dynamic _decodeValue(Map<String, dynamic> value) {
  if (value.containsKey('stringValue')) {
    return value['stringValue'];
  }
  if (value.containsKey('integerValue')) {
    return int.tryParse(value['integerValue'].toString()) ?? 0;
  }
  if (value.containsKey('doubleValue')) {
    return (value['doubleValue'] as num).toDouble();
  }
  if (value.containsKey('booleanValue')) {
    return value['booleanValue'] == true;
  }
  if (value.containsKey('timestampValue')) {
    return value['timestampValue'];
  }
  if (value.containsKey('nullValue')) {
    return null;
  }
  if (value.containsKey('arrayValue')) {
    final arrayValue = value['arrayValue'];
    if (arrayValue is! Map) {
      return const [];
    }
    final values = arrayValue['values'];
    if (values is! List) {
      return const [];
    }
    return values
        .whereType<Map>()
        .map((item) => _decodeValue(Map<String, dynamic>.from(item)))
        .toList();
  }
  if (value.containsKey('mapValue')) {
    final mapValue = value['mapValue'];
    if (mapValue is! Map) {
      return const <String, dynamic>{};
    }
    return _decodeFields(mapValue['fields']);
  }
  return null;
}

String _docId(String namePath) {
  final parts = namePath.split('/');
  return parts.isEmpty ? '' : parts.last;
}
