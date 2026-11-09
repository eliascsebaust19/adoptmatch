import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../network/api_client.dart';
import 'google_auth_service.dart';

class LaravelAuthService {
  final ApiClient _apiClient;
  final GoogleSignIn _googleSignIn;

  LaravelAuthService({ApiClient? apiClient, GoogleSignIn? googleSignIn})
      : _apiClient = apiClient ?? ApiClient(),
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: ['email', 'profile'],
              clientId: kIsWeb ? GoogleAuthService.webClientId : null,
              serverClientId: kIsWeb ? null : GoogleAuthService.webClientId,
            );

  /// Sign in with Google: Obtains the real Google idToken and exchanges it
  /// with Laravel 11 for a Sanctum Personal Access Token without Firebase.
  Future<Map<String, dynamic>?> signInWithGoogle() async {
    // The account picker gives the instance a head start on booting.
    final warmUp = ApiClient.warmUp();
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // Cancelled

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('Failed to obtain Google ID Token.');
      }

      await warmUp;
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

  static String normalizePhone(String input) {
    final raw = input.trim();
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (raw.startsWith('+') && digits.length >= 8 && digits.length <= 15) return '+$digits';
    if (digits.startsWith('880') && digits.length == 13) return '+$digits';
    if (digits.startsWith('0') && digits.length == 11) return '+880${digits.substring(1)}';
    throw Exception('Enter a valid phone number in international format.');
  }

  Future<void> requestPhoneOtp(String phone) async {
    final response = await _apiClient.dio.post('/auth/phone/request',
      data: {'phone': normalizePhone(phone)});
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('The server did not confirm OTP delivery.');
    }
  }

  Future<Map<String, dynamic>> verifyPhoneOtp(String phone, String token) async {
    final response = await _apiClient.dio.post('/auth/phone/verify', data: {
      'phone': normalizePhone(phone), 'token': token, 'device_name': 'mobile_otp',
    });
    if (response.statusCode != 200 || response.data['status'] != 'success' ||
        response.data['access_token'] == null || response.data['user'] == null) {
      throw Exception('The server did not verify this OTP.');
    }
    await ApiClient.saveToken(response.data['access_token'].toString());
    return Map<String, dynamic>.from(response.data as Map);
  }

  /// Standard Email & Password Authentication
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    // Wake the instance first so the 60s receive timeout covers a cold start
    // instead of the request racing a container that has not booted yet.
    await ApiClient.awaitWarmUp();
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
    await ApiClient.awaitWarmUp();
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

  /// Change the password on the server. Throws unless the server confirms it.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _apiClient.dio.post('/auth/password', data: {
      'current_password': currentPassword,
      'password': newPassword,
      'password_confirmation': newPassword,
    });
    if (response.statusCode != 200 || response.data['status'] != 'success') {
      throw Exception('The server did not change your password.');
    }
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
