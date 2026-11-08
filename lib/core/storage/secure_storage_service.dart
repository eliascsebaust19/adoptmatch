import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Saves the Sanctum Bearer token securely with SharedPreferences fallback for Web/Offline
  Future<void> saveAuthToken(String token) async {
    _memoryFallback[_keyAuthToken] = token;
    try {
      await _storage.write(key: _keyAuthToken, value: token);
    } catch (e) {
      debugPrint('[SecureStorageService] Hardware storage notice: $e');
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAuthToken, token);
    } catch (_) {}
  }

  /// Retrieves the saved Sanctum Bearer token with multi-tier fallback
  Future<String?> getAuthToken() async {
    try {
      final token = await _storage.read(key: _keyAuthToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    final mem = _memoryFallback[_keyAuthToken];
    if (mem != null && mem.isNotEmpty) return mem;

    try {
      final prefs = await SharedPreferences.getInstance();
      final pToken = prefs.getString(_keyAuthToken);
      if (pToken != null && pToken.isNotEmpty) return pToken;
    } catch (_) {}

    return null;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserProfile, jsonString);
      await prefs.setString('cached_user_id', user.id);
      await prefs.setString('cached_user_email', user.email);
      await prefs.setString('cached_user_name', user.name);
      await prefs.setString('cached_user_photo', user.avatarUrl);
      await prefs.setString('cached_user_role', user.role.code);
    } catch (_) {}
  }

  /// Retrieves the cached UserProfile with persistent fallback
  Future<UserProfile?> getUserProfile() async {
    String? raw;
    try {
      raw = await _storage.read(key: _keyUserProfile);
    } catch (_) {}
    raw ??= _memoryFallback[_keyUserProfile];

    if (raw == null || raw.isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_keyUserProfile);
      } catch (_) {}
    }

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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAuthToken);
      await prefs.remove(_keyUserProfile);
      await prefs.remove(_keyRefreshToken);
      await prefs.remove('cached_user_id');
      await prefs.remove('cached_user_email');
      await prefs.remove('cached_user_name');
      await prefs.remove('cached_user_photo');
      await prefs.remove('cached_user_role');
    } catch (_) {}
  }

  /// Checks if an active token exists
  Future<bool> hasValidToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
}
