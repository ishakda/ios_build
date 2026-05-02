import 'dart:convert';
import 'dart:io';

import 'package:supabase/supabase.dart';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final dryRun = options.containsKey('dry-run');
  final userId = _normalize(options['user-id']);
  final email = _normalizeEmail(options['email']);

  if ((userId == null && email == null) || (userId != null && email != null)) {
    _printUsage(
      'Provide exactly one of --user-id=<supabase-user-id> or --email=<email>.',
    );
    exitCode = 64;
    return;
  }

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
      r'dart run tool/bootstrap_first_admin.dart --email=admin@example.com --dry-run',
    );
    exitCode = 64;
    return;
  }

  final client = SupabaseClient(url, serviceRoleKey);

  try {
    final existingAdmins = await _loadExistingAdmins(client);
    final publicUser = await _loadPublicUser(
      client,
      userId: userId,
      email: email,
    );

    if (dryRun) {
      stdout.writeln(
        'Mode: dry-run\n'
        'Target: ${userId ?? email}\n'
        'Existing admins: ${existingAdmins.length}',
      );

      if (existingAdmins.isNotEmpty) {
        stdout.writeln(
          const JsonEncoder.withIndent('  ').convert(existingAdmins),
        );
      }

      if (publicUser == null) {
        stdout.writeln(
          'Target was not found in public.users. '
          'Bootstrap can still succeed if the auth user already exists.',
        );
      } else {
        stdout.writeln(
          'Resolved public.users candidate:\n'
          '${const JsonEncoder.withIndent('  ').convert(publicUser)}',
        );
      }
      return;
    }

    final response = await client.rpc(
      'bootstrap_first_admin',
      params: {'p_user_id': userId, 'p_email': email},
    );
    final payload = _asMap(response);

    stdout.writeln(
      'First admin bootstrapped successfully:\n'
      '${const JsonEncoder.withIndent('  ').convert(payload)}',
    );
  } on PostgrestException catch (error) {
    stderr.writeln(
      'Supabase RPC failed: ${error.message}'
      '${error.details == null ? '' : '\nDetails: ${error.details}'}',
    );
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Bootstrap failed: $error');
    exitCode = 1;
  }
}

Future<List<Map<String, dynamic>>> _loadExistingAdmins(
  SupabaseClient client,
) async {
  final response = await client
      .from('users')
      .select('id, name, email, role')
      .eq('role', 'admin')
      .order('createdAt');

  return (response as List)
      .cast<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

Future<Map<String, dynamic>?> _loadPublicUser(
  SupabaseClient client, {
  required String? userId,
  required String? email,
}) async {
  if (userId != null) {
    final response = await client
        .from('users')
        .select('id, name, email, role, isBanned, isSellerApproved')
        .eq('id', userId)
        .maybeSingle();
    return response == null ? null : Map<String, dynamic>.from(response);
  }

  final response = await client
      .from('users')
      .select('id, name, email, role, isBanned, isSellerApproved')
      .ilike('email', email!)
      .limit(1)
      .maybeSingle();
  return response == null ? null : Map<String, dynamic>.from(response);
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is List && value.isNotEmpty && value.first is Map) {
    return Map<String, dynamic>.from(value.first as Map);
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  throw StateError('Unexpected bootstrap response: $value');
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

    final separator = arg.indexOf('=');
    if (separator == -1) {
      options[arg.substring(2)] = 'true';
      continue;
    }

    final key = arg.substring(2, separator);
    final value = arg.substring(separator + 1);
    options[key] = value;
  }
  return options;
}

String? _normalize(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String? _normalizeEmail(String? value) {
  final trimmed = _normalize(value);
  if (trimmed == null) {
    return null;
  }
  return trimmed.toLowerCase();
}

void _printUsage(String message) {
  stderr.writeln(
    '$message\n'
    'Usage:\n'
    '  dart run tool/bootstrap_first_admin.dart --email=admin@example.com --dry-run\n'
    '  dart run tool/bootstrap_first_admin.dart --email=admin@example.com\n'
    '  dart run tool/bootstrap_first_admin.dart --user-id=<supabase-user-id>',
  );
}
