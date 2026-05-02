// ignore_for_file: use_null_aware_elements

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:supabase/supabase.dart';

const _defaultInput = 'firebase_auth_users.json';
const _defaultOutput = 'firebase_uid_map.json';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');
  final inputPath = options['input'] ?? _defaultInput;
  final outputPath = options['output'] ?? _defaultOutput;

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
      r'dart run tool/import_firebase_auth_users.dart --input=firebase_auth_users.json',
    );
    exitCode = 64;
    return;
  }

  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('Firebase auth export not found: $inputPath');
    exitCode = 66;
    return;
  }

  final users = _parseFirebaseUsers(await inputFile.readAsString());
  final client = SupabaseClient(url, serviceRoleKey);
  final mappings = <Map<String, dynamic>>[];
  var created = 0;
  var updated = 0;
  var skipped = 0;
  var failed = 0;

  stdout.writeln(
    'Found ${users.length} Firebase auth users. Mode: ${dryRun ? 'dry-run' : 'write'}',
  );

  for (final rawUser in users) {
    final firebaseUid =
        _asString(rawUser['localId']) ?? _asString(rawUser['uid']);
    final email = _asString(rawUser['email']);
    final phone = _asString(rawUser['phoneNumber']);

    if (firebaseUid == null || firebaseUid.isEmpty) {
      skipped++;
      stderr.writeln('SKIP missing Firebase uid: $rawUser');
      continue;
    }

    if ((email == null || email.isEmpty) && (phone == null || phone.isEmpty)) {
      skipped++;
      stderr.writeln('SKIP [$firebaseUid] missing email and phone');
      continue;
    }

    final claims = _parseClaims(rawUser['customAttributes']);
    final providerIds = _parseProviderIds(rawUser['providerUserInfo']);
    final name = _resolveName(rawUser, email: email, phone: phone);
    final photoUrl = _asString(rawUser['photoUrl']);
    final role = _asString(claims['role']) ?? 'buyer';
    final emailVerified = rawUser['emailVerified'] == true;
    final disabled = rawUser['disabled'] == true;
    final createdAt = _parseTimestamp(rawUser['createdAt']);
    final lastLoginAt = _parseTimestamp(rawUser['lastLoginAt']) ?? createdAt;

    try {
      final existingSupabaseUserId = dryRun
          ? null
          : await _findExistingSupabaseUserId(
              client,
              email: email,
              phone: phone,
            );

      if (dryRun) {
        final tempPassword = email != null && email.isNotEmpty
            ? _generateTempPassword()
            : null;
        stdout.writeln(
          'PLAN [$firebaseUid] '
          '${existingSupabaseUserId == null ? 'create' : 'update'} '
          'email=${email ?? '-'} phone=${phone ?? '-'} tempPassword=${tempPassword ?? '-'}',
        );
        mappings.add({
          'firebaseUid': firebaseUid,
          'supabaseUserId': existingSupabaseUserId,
          'email': email,
          'phone': phone,
          'temporaryPassword': tempPassword,
          'providers': providerIds,
        });
        continue;
      }

      final tempPassword = email != null && email.isNotEmpty
          ? _generateTempPassword()
          : null;
      final storeName = _asString(claims['storeName']);
      final storeDescription = _asString(claims['storeDescription']);
      final userMetadata = <String, dynamic>{
        'name': name,
        if (photoUrl case final value?) 'profileImageUrl': value,
        if (phone case final value?) 'phoneNumber': value,
        'role': role,
        if (storeName case final value?) 'storeName': value,
        if (storeDescription case final value?) 'storeDescription': value,
      };
      final appMetadata = <String, dynamic>{
        'firebase_uid': firebaseUid,
        'firebase_providers': providerIds,
        if (claims.isNotEmpty) 'firebase_claims': claims,
      };

      String supabaseUserId;
      if (existingSupabaseUserId == null) {
        final response = await client.auth.admin.createUser(
          AdminUserAttributes(
            email: email,
            phone: phone,
            password: tempPassword,
            emailConfirm: emailVerified,
            phoneConfirm: phone != null && phone.isNotEmpty,
            userMetadata: userMetadata,
            appMetadata: appMetadata,
            banDuration: disabled ? '876000h' : null,
          ),
        );
        final createdUser = response.user;
        if (createdUser == null) {
          throw StateError('Supabase admin createUser returned no user');
        }
        supabaseUserId = createdUser.id;
        created++;
      } else {
        await client.auth.admin.updateUserById(
          existingSupabaseUserId,
          attributes: AdminUserAttributes(
            email: email,
            phone: phone,
            password: tempPassword,
            emailConfirm: emailVerified,
            phoneConfirm: phone != null && phone.isNotEmpty,
            userMetadata: userMetadata,
            appMetadata: appMetadata,
            banDuration: disabled ? '876000h' : 'none',
          ),
        );
        supabaseUserId = existingSupabaseUserId;
        updated++;
      }

      await client.from('users').upsert({
        'id': supabaseUserId,
        'name': name,
        'email': email ?? '',
        'profileImageUrl': photoUrl,
        'phoneNumber': phone,
        'role': role,
        'storeName': storeName,
        'storeDescription': storeDescription,
        'createdAt': createdAt?.toUtc().toIso8601String(),
        'updatedAt': lastLoginAt?.toUtc().toIso8601String(),
      });

      mappings.add({
        'firebaseUid': firebaseUid,
        'supabaseUserId': supabaseUserId,
        'email': email,
        'phone': phone,
        'temporaryPassword': tempPassword,
        'providers': providerIds,
      });
      stdout.writeln(
        'OK   [$firebaseUid] -> $supabaseUserId email=${email ?? '-'}',
      );
    } catch (error) {
      failed++;
      stderr.writeln('FAIL [$firebaseUid] $error');
    }
  }

  final outputFile = File(outputPath);
  await outputFile.writeAsString(
    const JsonEncoder.withIndent('  ').convert(mappings),
  );

  stdout.writeln(
    'Done. created=$created updated=$updated skipped=$skipped failed=$failed',
  );
  stdout.writeln('UID map written to ${outputFile.path}');
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

List<Map<String, dynamic>> _parseFirebaseUsers(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const [];
  }

  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return decoded
          .cast<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    if (decoded is Map<String, dynamic>) {
      final users = decoded['users'];
      if (users is List) {
        return users
            .cast<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }
  } catch (_) {
    // Fall back to line-delimited JSON.
  }

  return raw
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .map((line) => jsonDecode(line) as Map)
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<String?> _findExistingSupabaseUserId(
  SupabaseClient client, {
  String? email,
  String? phone,
}) async {
  if (email != null && email.isNotEmpty) {
    final row = await client
        .from('users')
        .select('id')
        .eq('email', email)
        .maybeSingle();
    if (row != null) {
      return _asString(row['id']);
    }
  }

  if (phone != null && phone.isNotEmpty) {
    final row = await client
        .from('users')
        .select('id')
        .eq('phoneNumber', phone)
        .maybeSingle();
    if (row != null) {
      return _asString(row['id']);
    }
  }

  return null;
}

Map<String, dynamic> _parseClaims(Object? rawClaims) {
  final value = _asString(rawClaims);
  if (value == null || value.isEmpty) {
    return const {};
  }

  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
  } catch (_) {
    // Ignore malformed claims.
  }
  return const {};
}

List<String> _parseProviderIds(Object? providerUserInfo) {
  if (providerUserInfo is! List) {
    return const [];
  }

  return providerUserInfo
      .whereType<Map>()
      .map((item) => _asString(item['providerId']))
      .whereType<String>()
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

String _resolveName(
  Map<String, dynamic> rawUser, {
  required String? email,
  required String? phone,
}) {
  final displayName = _asString(rawUser['displayName']);
  if (displayName != null && displayName.trim().isNotEmpty) {
    return displayName.trim();
  }
  if (email != null && email.contains('@')) {
    return email.split('@').first;
  }
  if (phone != null && phone.isNotEmpty) {
    return phone;
  }
  return 'User';
}

DateTime? _parseTimestamp(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
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

String? _asString(Object? value) {
  if (value == null) {
    return null;
  }
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String _generateTempPassword() {
  const alphabet =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#\$%^&*';
  final random = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 20; i++) {
    buffer.write(alphabet[random.nextInt(alphabet.length)]);
  }
  return buffer.toString();
}
