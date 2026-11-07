import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../features/auth/bloc/auth_bloc.dart';

class SecureStorageService {
  SecureStorageService._internal();
  static final SecureStorageService instance = SecureStorageService._internal();

  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserProfile = 'user_profile';
  static const String _keyRefreshToken = 'refresh_token';

  final Map<String, String> _memoryFallback = {};

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  /// Saves the Sanctum Bearer token securely
  Future<void> saveAuthToken(String token) async {
    _memoryFallback[_keyAuthToken] = token;
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      debugPrint('[SecureStorageService] Hardware storage notice: $e');
    }
  }

  /// Retrieves the saved Sanctum Bearer token
  Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: _keyAuthToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}
    return _memoryFallback[_keyAuthToken];
  }

  /// Saves user profile JSON
  Future<void> saveUserProfile(UserProfile user) async {
    final jsonString = jsonEncode(user.toJson());
    _memoryFallback[_keyUserProfile] = jsonString;
    try {
      await _storage.write(key: _keyUserProfile, value: jsonString);
    } catch (e) {
      debugPrint('[SecureStorageService] Hardware storage notice: $e');
    }
  }

  /// Retrieves the cached UserProfile
  Future<UserProfile?> getUserProfile() async {
    String? raw;
    try {
      raw = await _storage.read(key: _keyUserProfile);
    } catch (_) {}
    raw ??= _memoryFallback[_keyUserProfile];

    if (raw == null || raw.isEmpty) return null;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } catch (e) {
      debugPrint('[SecureStorageService] Error decoding user profile: $e');
      return null;
    }
  }

  /// Clears all secure auth session data
  Future<void> clearSession() async {
    _memoryFallback.clear();
    try {
      await _storage.delete(key: _keyAuthToken);
      await _storage.delete(key: _keyUserProfile);
      await _storage.delete(key: _keyRefreshToken);
    } catch (_) {}
  }

  /// Checks if an active token exists
  Future<bool> hasValidToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
