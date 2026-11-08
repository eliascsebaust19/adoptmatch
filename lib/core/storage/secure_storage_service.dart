import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/bloc/auth_bloc.dart';

/// Session tokens and profiles are kept only in platform secure storage.
/// Writes fail closed; ordinary preferences are used solely to purge old plaintext copies.
class SecureStorageService {
  SecureStorageService._internal();
  static final SecureStorageService instance = SecureStorageService._internal();

  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyRefreshToken = 'refresh_token';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(resetOnError: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<void> saveAuthToken(String token) async {
    if (token.trim().isEmpty) throw Exception('Refusing to store an empty session token.');
    await _storage.write(key: _keyAuthToken, value: token);
  }

  Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: _keyAuthToken);
      return token == null || token.isEmpty ? null : token;
    } catch (e) {
      debugPrint('[SecureStorageService] Token read unavailable: $e');
      return null;
    }
  }

  Future<void> saveUserProfile(UserProfile user) async {
    await _storage.write(key: _keyUserProfile, value: jsonEncode(user.toJson()));
  }

  Future<UserProfile?> getUserProfile() async {
    try {
      final raw = await _storage.read(key: _keyUserProfile);
      if (raw == null || raw.isEmpty) return null;
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[SecureStorageService] Profile read unavailable: $e');
      return null;
    }
  }

  Future<void> clearSession() async {
    try {
      await _storage.delete(key: _keyAuthToken);
      await _storage.delete(key: _keyUserProfile);
      await _storage.delete(key: _keyRefreshToken);
    } catch (e) {
      debugPrint('[SecureStorageService] Secure delete warning: $e');
    }
    await purgeLegacyPlaintextCopies();
  }

  /// Removes plaintext copies left behind by older builds on every platform.
  Future<void> purgeLegacyPlaintextCopies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in [_keyAuthToken, _keyUserProfile, _keyRefreshToken,
        'cached_user_id', 'cached_user_email', 'cached_user_name',
        'cached_user_photo', 'cached_user_role']) {
        await prefs.remove(key);
      }
    } catch (_) {}
  }

  Future<bool> hasValidToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
