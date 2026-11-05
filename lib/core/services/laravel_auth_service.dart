import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../network/api_client.dart';

class LaravelAuthService {
  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  LaravelAuthService({ApiClient? apiClient, GoogleSignIn? googleSignIn})
      : _apiClient = apiClient ?? ApiClient(),
        _googleSignIn = googleSignIn ?? GoogleSignIn(scopes: ['email', 'profile']);

  /// Sign in with Google: Obtains the real Google idToken and exchanges it
  /// with Laravel 11 for a Sanctum Personal Access Token without Firebase.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      final response = await _apiClient.dio.post('/auth/google', data: {
        'id_token': idToken,
      });

      if (response.statusCode == 200 && (response.data['status'] == 'success' || response.data['success'] == true)) {
        final token = (response.data['access_token'] ?? response.data['token']) as String;
        await ApiClient.saveToken(token);
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('[LaravelAuthService] Google Sign-In Dio error: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[LaravelAuthService] Google Sign-In error: $e');
      rethrow;
    }
  }

  /// Standard Email & Password Authentication
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.dio.post('/auth/login', data: {
      'email': email,
      'password': password,
    });

    if (response.data['status'] == 'success' || response.data['success'] == true) {
      final token = (response.data['access_token'] ?? response.data['token']) as String;
      await ApiClient.saveToken(token);
    }
    return response.data;
  }

  /// Register new user with Role (adopter, pet_owner, shelter)
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) async {
    final response = await _apiClient.dio.post('/auth/register', data: {
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'phone': phone,
    });

    if (response.data['status'] == 'success' || response.data['success'] == true) {
      final token = (response.data['access_token'] ?? response.data['token']) as String;
      await ApiClient.saveToken(token);
    }
    return response.data;
  }

  /// Get current authenticated user profile
  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _apiClient.dio.get('/me');
      if (response.data['status'] == 'success' || response.data['success'] == true) {
        return response.data['user'] ?? response.data['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sign out
  Future<void> logout() async {
    try {
      await _apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await ApiClient.clearToken();
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.signOut();
      }
    }
  }
}
