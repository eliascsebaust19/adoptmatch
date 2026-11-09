import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../config/auth_config.dart';
import '../network/api_client.dart';
import '../storage/secure_storage_service.dart';

class GoogleAuthResult {
  final bool success;
  final UserProfile? user;
  final String? errorMessage;
  final bool wasCancelled;
  final bool isNewUser;

  const GoogleAuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.wasCancelled = false,
    this.isNewUser = false,
  });
}

class GoogleAuthService {
  /// Kept for existing callers; the value lives in [AuthConfig] only.
  static String get webClientId => AuthConfig.googleWebClientId;

  static String get backendBaseUrl => ApiClient.rootUrl;

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? webClientId : null,
    serverClientId: kIsWeb ? null : webClientId,
  );

  /// Performs Google Sign-In with resilience:
  /// 1. Tries Native GoogleSignIn (Android/iOS Account Picker or Web OAuth)
  /// 2. If Google Sign-In succeeds, uses the real Google ID Token & profile
  /// 3. If running on Web Localhost and origin is unregistered in Google Cloud Console,
  ///    gracefully falls back to direct Laravel 11 backend sync so dev/testing is never blocked.
  /// 4. Syncs with Laravel 11 Backend (/api/v1/auth/google) for Sanctum Bearer token.
  static Future<GoogleAuthResult> signIn() async {
    if (!AuthConfig.isGoogleConfigured) {
      return const GoogleAuthResult(
        success: false,
        errorMessage: AuthConfig.notConfiguredMessage,
      );
    }
    try {
      debugPrint('[GoogleAuthService] Initiating Google Sign-In flow...');

      GoogleSignInAccount? account;
      String? nativeError;
      try {
        account = await _googleSignIn.signIn();
      } catch (nativeErr) {
        nativeError = nativeErr.toString();
        debugPrint('[GoogleAuthService] Native GoogleSignIn error: $nativeErr');
      }

      if (account == null) {
        if (nativeError != null) {
          String userFriendlyMsg = nativeError;
          if (nativeError.contains('ApiException: 10') ||
              nativeError.contains('DEVELOPER_ERROR')) {
            userFriendlyMsg =
                'Google Sign-In configuration error (ApiException 10). Register this '
                'build\'s SHA-1 for package com.adoptmatch.adoptmatch in Google Cloud '
                'Console and use the matching Web client ID. See docs/AUTH_SETUP.md.';
          }
          return GoogleAuthResult(
            success: false,
            errorMessage: userFriendlyMsg,
          );
        }
        return const GoogleAuthResult(
          success: false,
          wasCancelled: true,
          errorMessage: 'Google Sign-In was cancelled.',
        );
      }

      String? idToken;

      try {
        final authHeaders = await account.authentication;
        idToken = authHeaders.idToken;
      } catch (tokenErr) {
        debugPrint('[GoogleAuthService] Token retrieval error: $tokenErr');
      }

      if (idToken == null || idToken.isEmpty) {
        return const GoogleAuthResult(
          success: false,
          errorMessage: AuthConfig.missingIdTokenMessage,
        );
      }

      // Real user details strictly from authenticated Google account
      final userEmail = account.email;
      final userName = (account.displayName?.isNotEmpty == true)
          ? account.displayName!
          : account.email.split('@').first;
      final userPhoto = account.photoUrl ?? '';
      final googleId = account.id;

      UserProfile? userProfile;
      bool isNewUser = false;
      String? backendError;

      // Sync with Laravel 11 Backend API
      try {
        final res = await http
            .post(
              Uri.parse('$backendBaseUrl/api/v1/auth/google'),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
              body: jsonEncode({
                'id_token': idToken,
                'idToken': idToken,
                'device_name': 'flutter_google',
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          isNewUser = data['is_new_user'] == true;
          final u = data['user'] ?? data['data'];
          final sanctumToken = data['access_token'] ??
              data['token'] ??
              (data['tokens'] != null ? data['tokens']['accessToken'] : null);

          if (sanctumToken != null) {
            await SecureStorageService.instance.saveAuthToken(
              sanctumToken.toString(),
            );
            await ApiClient.saveToken(sanctumToken.toString());
          }

          if (u != null) {
            userProfile = UserProfile(
              id: u['id']?.toString() ?? googleId,
              name: u['name'] ?? userName,
              email: u['email'] ?? userEmail,
              phone: u['phone'] ?? '',
              role: UserRole.fromCode(u['role']?.toString()),
              avatarUrl: u['avatar'] ?? userPhoto,
              googlePhotoUrl: userPhoto,
              location: u['location']?.toString() ?? 'Dhaka, Bangladesh',
              bio: u['bio']?.toString() ?? 'Animal advocate & pet rescuer',
              preferredPetType: 'All Pets',
              isVerified: true,
            );
          }
        } else {
          String? serverMsg;
          try {
            final parsed = jsonDecode(res.body);
            serverMsg = parsed['message']?.toString();
          } catch (_) {}
          backendError = serverMsg ??
              'AdoptMatch server rejected the sign-in (HTTP ${res.statusCode}).';
        }
      } on TimeoutException {
        backendError =
            'The AdoptMatch server took too long to respond. The free-tier server is waking up — please try again in a few moments.';
        debugPrint('[GoogleAuthService] Backend request timed out.');
      } catch (backendErr) {
        backendError = 'Could not reach the AdoptMatch server: $backendErr';
        debugPrint('[GoogleAuthService] Backend sync failed: $backendErr');
      }

      // Fail closed: without a server-issued session there is no signed-in user.
      if (userProfile == null) {
        return GoogleAuthResult(
          success: false,
          errorMessage: backendError ??
              'Google verified your account, but the AdoptMatch server did not issue a session. Please try again.',
        );
      }

      final sessionToken = await SecureStorageService.instance.getAuthToken();
      if (sessionToken == null || sessionToken.isEmpty) {
        return const GoogleAuthResult(
          success: false,
          errorMessage:
              'The server did not return a session token. Please sign in again.',
        );
      }

      await SecureStorageService.instance.saveUserProfile(userProfile);

      return GoogleAuthResult(
        success: true,
        user: userProfile,
        isNewUser: isNewUser,
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Exception in Google Sign-In: $e');
      return GoogleAuthResult(success: false, errorMessage: e.toString());
    }
  }

  /// Sign out from Google and clear local session
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => null,
      );
    } catch (_) {}

    try {
      await SecureStorageService.instance.clearSession();
      final prefs = await SharedPreferences.getInstance().timeout(
        const Duration(milliseconds: 300),
      );
      await prefs.remove('auth_token');
      await prefs.remove('cached_user_id');
      await prefs.remove('cached_user_email');
      await prefs.remove('cached_user_name');
      await prefs.remove('cached_user_photo');
      await prefs.remove('cached_user_role');
      await ApiClient.clearToken();
    } catch (_) {}
  }
}
