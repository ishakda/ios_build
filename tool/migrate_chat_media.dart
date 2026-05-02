import 'dart:io';

import 'package:supabase/supabase.dart';

const _bucket = 'chat-media';
const _messagesTable = 'messages';

Future<void> main(List<String> args) async {
  final dryRun = args.contains('--dry-run');
  final verbose = args.contains('--verbose');
  final url = Platform.environment['SUPABASE_URL'];
  final serviceRoleKey = Platform.environment['SUPABASE_SERVICE_ROLE_KEY'];

  if (url == null || url.isEmpty || serviceRoleKey == null || serviceRoleKey.isEmpty) {
    stderr.writeln(
      'Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY.\n'
      'Example:\n'
      r'$env:SUPABASE_URL="https://your-project.supabase.co"' '\n'
      r'$env:SUPABASE_SERVICE_ROLE_KEY="your-service-role-key"' '\n'
      r'dart run tool/migrate_chat_media.dart --dry-run',
    );
    exitCode = 64;
    return;
  }

  final client = SupabaseClient(url, serviceRoleKey);
  final messages = await _loadMessages(client);
  var migrated = 0;
  var skipped = 0;
  var missing = 0;
  var failed = 0;

  stdout.writeln(
    'Found ${messages.length} chat messages with image payloads. '
    'Mode: ${dryRun ? 'dry-run' : 'write'}',
  );

  for (final message in messages) {
    final id = message['id']?.toString() ?? '';
    final chatId = message['chatId']?.toString() ?? '';
    final senderId = message['senderId']?.toString() ?? '';
    final imageValue = message['imageUrl']?.toString() ?? '';

    final oldPath = _extractStoragePath(imageValue);
    if (oldPath == null) {
      skipped++;
      if (verbose) {
        stdout.writeln('SKIP [$id] unsupported imageUrl format: $imageValue');
      }
      continue;
    }

    final newPath = _buildNewPath(
      oldPath: oldPath,
      chatId: chatId,
      senderId: senderId,
    );

    if (newPath == null) {
      skipped++;
      if (verbose) {
        stdout.writeln('SKIP [$id] does not match old layout: $oldPath');
      }
      continue;
    }

    if (newPath == oldPath && imageValue == newPath) {
      skipped++;
      continue;
    }

    try {
      if (dryRun) {
        stdout.writeln('PLAN [$id] $oldPath -> $newPath');
        migrated++;
        continue;
      }

      final sourceExists = await _objectExists(client, oldPath);
      if (!sourceExists) {
        missing++;
        stdout.writeln('MISS [$id] object not found: $oldPath');
        continue;
      }

      final destinationExists = await _objectExists(client, newPath);
      if (!destinationExists) {
        await client.storage.from(_bucket).move(oldPath, newPath);
      } else if (verbose) {
        stdout.writeln('KEEP [$id] destination already exists: $newPath');
      }

      await client
          .from(_messagesTable)
          .update({'imageUrl': newPath})
          .eq('id', id);

      migrated++;
      stdout.writeln('OK   [$id] $oldPath -> $newPath');
    } catch (error) {
      failed++;
      stderr.writeln('FAIL [$id] $oldPath -> $newPath :: $error');
    }
  }

  stdout.writeln(
    'Done. migrated=$migrated skipped=$skipped missing=$missing failed=$failed',
  );
}

Future<List<Map<String, dynamic>>> _loadMessages(SupabaseClient client) async {
  final results = <Map<String, dynamic>>[];
  var from = 0;
  const pageSize = 1000;

  while (true) {
    final page = await client
        .from(_messagesTable)
        .select('id, chatId, senderId, receiverId, imageUrl')
        .not('imageUrl', 'is', null)
        .range(from, from + pageSize - 1);

    final rows = (page as List)
        .cast<Map<String, dynamic>>()
        .where((row) => (row['imageUrl']?.toString().isNotEmpty ?? false))
        .toList();

    results.addAll(rows);
    if (rows.length < pageSize) {
      break;
    }

    from += pageSize;
  }

  return results;
}

String? _extractStoragePath(String value) {
  if (value.isEmpty) {
    return null;
  }

  if (value.startsWith('chats/')) {
    return value;
  }

  final uri = Uri.tryParse(value);
  if (uri == null) {
    return null;
  }

  final marker = '/$_bucket/';
  final path = uri.path;
  final markerIndex = path.indexOf(marker);
  if (markerIndex == -1) {
    return null;
  }

  final extracted = path.substring(markerIndex + marker.length);
  return extracted.isEmpty ? null : extracted;
}

String? _buildNewPath({
  required String oldPath,
  required String chatId,
  required String senderId,
}) {
  final segments = oldPath.split('/');
  if (segments.length < 3 || segments.first != 'chats') {
    return null;
  }

  if (segments.length >= 4 && segments[1] == chatId && segments[2] == senderId) {
    return oldPath;
  }

  if (segments.length != 3 || chatId.isEmpty || senderId.isEmpty) {
    return null;
  }

  final filename = segments[2];
  return 'chats/$chatId/$senderId/$filename';
}

Future<bool> _objectExists(SupabaseClient client, String path) async {
  final normalized = path.replaceAll('\\', '/');
  final slash = normalized.lastIndexOf('/');
  if (slash == -1) {
    return false;
  }

  final folder = normalized.substring(0, slash);
  final filename = normalized.substring(slash + 1);
  final objects = await client.storage.from(_bucket).list(path: folder);

  return objects.any((object) => object.name == filename);
}
