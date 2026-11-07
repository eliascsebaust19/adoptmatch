import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../bloc/auth_bloc.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorageService _secureStorage;
  final LocalStorageService _localStorage;

  AuthRepository({
    ApiClient? apiClient,
    SecureStorageService? secureStorage,
    LocalStorageService? localStorage,
  })  : _apiClient = apiClient ?? ApiClient(),
        _secureStorage = secureStorage ?? SecureStorageService.instance,
        _localStorage = localStorage ?? LocalStorageService.instance;

  /// Authenticate user via Laravel API (POST /auth/login)
  Future<UserProfile> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/login',
        data: {
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (token == null || userMap == null) {
        throw Exception('Invalid login response from authentication server.');
      }

      final user = UserProfile.fromJson(userMap);

      // Persist token and profile securely
      await _secureStorage.saveAuthToken(token);
      await _secureStorage.saveUserProfile(user);

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ??
          (e.response?.statusCode == 401
              ? 'Invalid email or password.'
              : 'Unable to connect to authentication server. Please check your internet.');
      throw Exception(msg);
    } catch (e) {
      rethrow;
    }
  }

  /// Register new adopter account via Laravel API (POST /auth/register)
  Future<UserProfile> register({
    required String name,
    required String email,
    required String password,
    String? phone,
    String role = 'adopter',
  }) async {
    try {
      final response = await _apiClient.dio.post(
        '/auth/register',
        data: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          if (phone != null && phone.isNotEmpty) 'phone': phone.trim(),
          'role': role,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (token == null || userMap == null) {
        throw Exception('Registration succeeded but session token was missing.');
      }

      final user = UserProfile.fromJson(userMap);

      await _secureStorage.saveAuthToken(token);
      await _secureStorage.saveUserProfile(user);

      return user;
    } on DioException catch (e) {
      final msg = e.response?.data?['message']?.toString() ??
          'Registration failed. Please verify your details.';
      throw Exception(msg);
    }
  }

  /// Checks if a valid persistent session exists and verifies with GET /auth/me
  Future<UserProfile?> verifyCurrentSession() async {
    final token = await _secureStorage.getAuthToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await _apiClient.dio.get('/auth/me');
      final data = response.data as Map<String, dynamic>;
      final userMap = data['user'] as Map<String, dynamic>?;

      if (userMap != null) {
        final user = UserProfile.fromJson(userMap);
        await _secureStorage.saveUserProfile(user);
        return user;
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        debugPrint('[AuthRepository] Session token expired or revoked. Clearing local session.');
        await _secureStorage.clearSession();
        return null;
      }
      // If network is offline, fall back to cached secure profile
      final cached = await _secureStorage.getUserProfile();
      if (cached != null) return cached;
    } catch (e) {
      debugPrint('[AuthRepository] Error verifying session: $e');
    }

    return null;
  }

  /// Complete Logout: Revoke server token, clear secure storage & wipe user cache
  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout').timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('[AuthRepository] Server logout notice (token may already be invalidated): $e');
    } finally {
      await _secureStorage.clearSession();
      await _localStorage.clearAllUserData();
    }
  }
}

