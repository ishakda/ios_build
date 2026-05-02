import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:untitled1/core/api/api_client.dart';
import 'package:untitled1/core/config/supabase_config.dart';
import 'package:untitled1/core/constants/supabase_constants.dart';
import 'package:untitled1/core/services/supabase_service.dart';
import 'package:untitled1/features/auth/domain/entities/user.dart';
import 'dart:async';

class EmailVerificationRequiredException implements Exception {
  const EmailVerificationRequiredException([
    this.message =
        'Registration successful. Please verify your email, then sign in.',
  ]);

  final String message;

  @override
  String toString() => message;
}

class AccountSuspendedException implements Exception {
  const AccountSuspendedException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class AuthRemoteDataSource {
  Future<User> login(String email, String password);
  Future<User> register(
    String name,
    String email,
    String password,
    String role,
  );
  Future<User> signInWithGoogle();
  Future<void> logout();
  Future<User?> getCurrentUser();
  Future<User> updateUser(User user);
  Future<List<User>> searchUsers(String query);
  Future<User?> getUserById(String userId);
  Future<void> sendPasswordResetEmail(String email);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl({required this.apiClient});

  supabase.SupabaseClient get _client => SupabaseService.client;

  String get _nowIso => DateTime.now().toUtc().toIso8601String();

  GoogleSignIn get _googleSignIn => GoogleSignIn(
    clientId: SupabaseConfig.googleIosClientId.isEmpty
        ? null
        : SupabaseConfig.googleIosClientId,
    serverClientId: SupabaseConfig.googleWebClientId.isEmpty
        ? null
        : SupabaseConfig.googleWebClientId,
  );

  Future<User?> _getOwnUserById(String userId) async {
    final data = await _client
        .from(SupabaseTables.users)
        .select()
        .eq('id', userId)
        .maybeSingle();
    if (data == null) {
      return null;
    }
    final user = User.fromMap(data);
    final authUser = _client.auth.currentUser;
    if (authUser?.id == userId) {
      return user.copyWith(isEmailVerified: _isEmailVerified(authUser!));
    }
    return user;
  }

  bool _isEmailVerified(supabase.User authUser) {
    return authUser.emailConfirmedAt != null ||
        authUser.userMetadata?['email_verified'] == true;
  }

  Future<void> _upsertPublicUser(User user, {bool isNew = false}) async {
    final payload = <String, dynamic>{...user.toMap(), 'updatedAt': _nowIso};

    if (isNew) {
      payload['createdAt'] = _nowIso;
    }

    await _client.from(SupabaseTables.users).upsert(payload);
  }

  Future<void> _assertAccountActive(User user) async {
    if (!user.isBanned) {
      return;
    }

    await _client.auth.signOut();
    final reason = user.banReason?.trim();
    throw AccountSuspendedException(
      reason == null || reason.isEmpty
          ? 'Your account has been suspended. Contact support for help.'
          : 'Your account has been suspended: $reason',
    );
  }

  User _mapRpcUserResponse(dynamic response) {
    if (response is Map) {
      return User.fromMap(Map<String, dynamic>.from(response));
    }
    if (response is List && response.isNotEmpty && response.first is Map) {
      return User.fromMap(Map<String, dynamic>.from(response.first as Map));
    }
    throw Exception('Profile update returned an unexpected response');
  }

  Future<User> _ensureSignedInUser({
    String? fallbackName,
    String fallbackRole = 'buyer',
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw Exception('Supabase user is null after Google Sign-In');
    }

    final existingUser = await _getOwnUserById(authUser.id);
    if (existingUser != null) {
      await _assertAccountActive(existingUser);
      return existingUser;
    }

    final newUser = _buildUserFromAuth(
      authUser,
      fallbackName: fallbackName,
      fallbackRole: fallbackRole,
    );
    await _upsertPublicUser(newUser, isNew: true);
    await _assertAccountActive(newUser);
    return newUser;
  }

  bool _shouldFallbackToOAuth(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('sign_in_failed') ||
        message.contains('api exception: 10') ||
        message.contains('error 10') ||
        message.contains('developer_error') ||
        message.contains('12500') ||
        message.contains('12501') ||
        message.contains('network_error') ||
        message.contains('no id token') ||
        message.contains('no access token');
  }

  Future<User> _signInWithGoogleOAuthFallback() async {
    final authStream = _client.auth.onAuthStateChange;
    final completer = Completer<supabase.User>();
    late final StreamSubscription<supabase.AuthState> subscription;

    subscription = authStream.listen((state) {
      final user = state.session?.user ?? _client.auth.currentUser;
      if (!completer.isCompleted &&
          user != null &&
          (state.event == supabase.AuthChangeEvent.signedIn ||
              state.event == supabase.AuthChangeEvent.initialSession ||
              state.event == supabase.AuthChangeEvent.tokenRefreshed ||
              state.event == supabase.AuthChangeEvent.userUpdated)) {
        completer.complete(user);
      }
    });

    try {
      await _client.auth.signInWithOAuth(
        supabase.OAuthProvider.google,
        redirectTo: kIsWeb ? null : SupabaseConfig.redirectUrl,
        authScreenLaunchMode: kIsWeb
            ? supabase.LaunchMode.platformDefault
            : supabase.LaunchMode.externalApplication,
      );

      await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () => throw Exception(
          'Google OAuth sign-in did not return to the app. '
          'Verify the Supabase redirect URL and mobile deep link setup.',
        ),
      );

      return _ensureSignedInUser(fallbackRole: 'buyer');
    } finally {
      await subscription.cancel();
    }
  }

  User _buildUserFromAuth(
    supabase.User authUser, {
    String? fallbackName,
    String fallbackRole = 'buyer',
    String? fallbackStoreName,
    String? fallbackStoreDescription,
  }) {
    final metadata = authUser.userMetadata ?? const {};
    final name =
        (metadata['name'] ??
                metadata['full_name'] ??
                authUser.email?.split('@').first)
            ?.toString() ??
        fallbackName ??
        'User';

    return User(
      id: authUser.id,
      name: fallbackName ?? name,
      email: authUser.email ?? '',
      profileImageUrl: (metadata['profileImageUrl'] ?? metadata['avatar_url'])
          ?.toString(),
      phoneNumber: metadata['phoneNumber']?.toString(),
      role: (metadata['role'] ?? fallbackRole).toString(),
      storeName: (metadata['storeName'] ?? fallbackStoreName)?.toString(),
      storeDescription:
          (metadata['storeDescription'] ?? fallbackStoreDescription)
              ?.toString(),
      storeLogo: metadata['storeLogo']?.toString(),
      isSellerApproved: metadata['isSellerApproved'] == true,
      isVerifiedSeller: metadata['isVerifiedSeller'] == true,
      verificationLevel: (metadata['verificationLevel'] ?? 'none').toString(),
      trustScore: (metadata['trustScore'] is num)
          ? (metadata['trustScore'] as num).toDouble()
          : double.tryParse(metadata['trustScore']?.toString() ?? '') ?? 0,
      isBanned: metadata['isBanned'] == true,
      banReason: metadata['banReason']?.toString(),
      isCodBlocked: metadata['isCodBlocked'] == true,
      isEmailVerified: _isEmailVerified(authUser),
    );
  }

  @override
  Future<User?> getUserById(String userId) async {
    try {
      if (_client.auth.currentUser?.id == userId) {
        return _getOwnUserById(userId);
      }

      final data = await _client
          .from(SupabaseTables.userPublicProfiles)
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (data != null) {
        return User.fromMap(data);
      }
      return null;
    } catch (e) {
      developer.log("Get User By ID Error: $e");
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } catch (e) {
      developer.log("Password Reset Error: $e");
      rethrow;
    }
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    try {
      if (query.isEmpty) return [];

      final currentUserId = _client.auth.currentUser?.id;
      dynamic request = _client
          .from(SupabaseTables.userPublicProfiles)
          .select()
          .or('name.ilike.%$query%,storeName.ilike.%$query%');

      if (currentUserId != null) {
        request = request.neq('id', currentUserId);
      }

      final response = await request.limit(20);

      return response.map((item) => User.fromMap(item)).toList();
    } catch (e) {
      developer.log("Search Users Error: $e");
      rethrow;
    }
  }

  @override
  Future<User> updateUser(User user) async {
    try {
      final updatedUser = _mapRpcUserResponse(
        await _client.rpc(
          'update_own_profile',
          params: {'p_profile': user.toMap()},
        ),
      );
      if (_client.auth.currentUser?.id == user.id) {
        await _client.auth.updateUser(
          supabase.UserAttributes(
            data: {
              'name': updatedUser.name,
              'profileImageUrl': updatedUser.profileImageUrl,
              'phoneNumber': updatedUser.phoneNumber,
              'storeName': updatedUser.storeName,
              'storeDescription': updatedUser.storeDescription,
              'storeLogo': updatedUser.storeLogo,
            },
          ),
        );
      }
      await _assertAccountActive(updatedUser);
      final authUser = _client.auth.currentUser;
      return authUser?.id == updatedUser.id
          ? updatedUser.copyWith(isEmailVerified: _isEmailVerified(authUser!))
          : updatedUser;
    } catch (e) {
      developer.log("Update User Error: $e");
      rethrow;
    }
  }

  @override
  Future<User> login(String email, String password) async {
    try {
      final authResponse = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final authUser = authResponse.user ?? _client.auth.currentUser;

      if (authUser != null) {
        final existingUser = await _getOwnUserById(authUser.id);
        if (existingUser != null) {
          await _assertAccountActive(existingUser);
          return existingUser;
        }

        final newUser = _buildUserFromAuth(authUser, fallbackRole: 'buyer');
        await _upsertPublicUser(newUser, isNew: true);
        await _assertAccountActive(newUser);
        return newUser;
      }
      throw Exception('Login failed');
    } catch (e) {
      developer.log("Login Error: $e");
      rethrow;
    }
  }

  @override
  Future<User> register(
    String name,
    String email,
    String password,
    String role,
  ) async {
    try {
      final authResponse = await _client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'role': role,
          'storeName': role == 'seller' ? '$name Store' : null,
          'storeDescription': role == 'seller'
              ? 'Premium products for modern lifestyle.'
              : null,
        },
      );
      final authUser = authResponse.user ?? _client.auth.currentUser;

      if (authUser != null) {
        final user = User(
          id: authUser.id,
          name: name,
          email: email,
          role: role,
          storeName: role == 'seller' ? '$name Store' : null,
          storeDescription: role == 'seller'
              ? 'Premium products for modern lifestyle.'
              : null,
        );

        try {
          await _upsertPublicUser(user, isNew: true);
        } catch (e) {
          developer.log('Register user profile sync deferred: $e');
        }

        if (authResponse.session == null &&
            _client.auth.currentSession == null) {
          throw const EmailVerificationRequiredException();
        }

        await _assertAccountActive(user);
        return user;
      }
      throw Exception('Registration failed');
    } catch (e) {
      developer.log("Registration Error: $e");
      rethrow;
    }
  }

  @override
  Future<User> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google Sign-In cancelled by user');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;
      if (accessToken == null || idToken == null) {
        throw Exception('Google Sign-In did not return a valid token pair');
      }

      await _client.auth.signInWithIdToken(
        provider: supabase.OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      return _ensureSignedInUser(
        fallbackName: googleUser.displayName ?? 'Google User',
        fallbackRole: 'buyer',
      );
    } catch (e) {
      if (!kIsWeb && _shouldFallbackToOAuth(e)) {
        developer.log(
          'Google native sign-in failed, falling back to OAuth browser flow: $e',
        );
        try {
          await _googleSignIn.signOut();
        } catch (_) {
          // Ignore sign-out cleanup failures before browser OAuth.
        }
        return _signInWithGoogleOAuthFallback();
      }
      developer.log("Google Sign-In Error: $e");
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    await _client.auth.signOut();
    await GoogleSignIn().signOut();
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final authUser = _client.auth.currentUser;
      if (authUser == null) {
        return null;
      }

      final existingUser = await _getOwnUserById(authUser.id);
      if (existingUser != null) {
        await _assertAccountActive(existingUser);
        return existingUser;
      }

      final fallbackUser = _buildUserFromAuth(authUser, fallbackRole: 'buyer');
      await _upsertPublicUser(fallbackUser, isNew: true);
      await _assertAccountActive(fallbackUser);

      return fallbackUser;
    } catch (e) {
      developer.log("Get Current User Error: $e");
      rethrow;
    }
  }
}

class UserMapper {
  static User fromJson(Map<String, dynamic> json) {
    return User.fromMap(json);
  }
}
