import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../config/auth_config.dart';
import '../network/api_client.dart';
import '../network/network_error.dart';
import '../storage/secure_storage_service.dart';
import '../supabase/adoptmatch_supabase.dart';

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

  /// Shared client for the token exchange: same timeouts and headers as every
  /// other API call.
  static final ApiClient _apiClient = ApiClient();

  @visibleForTesting
  static GoogleSignIn? mockGoogleSignIn;

  static GoogleSignIn get _signInClient => mockGoogleSignIn ?? _defaultGoogleSignIn;

  static final GoogleSignIn _defaultGoogleSignIn = GoogleSignIn(
    scopes: const ['email', 'profile', 'openid'],
    clientId: kIsWeb ? webClientId : null,
    serverClientId: webClientId,
  );

  /// Performs Google Sign-In with resilience:
  /// 1. Tries Native GoogleSignIn (Android/iOS Account Picker or Web OAuth)
  /// 2. If Google Sign-In succeeds, uses the real Google ID Token & profile
  /// 3. If running on Web Localhost and origin is unregistered in Google Cloud Console,
  ///    gracefully falls back to direct Laravel 11 backend sync so dev/testing is never blocked.
  /// 4. Syncs with Supabase Auth or Laravel 11 Backend (/auth/google) for Bearer token.
  static Future<GoogleAuthResult> signIn() async {
    if (!AuthConfig.isGoogleConfigured) {
      return const GoogleAuthResult(
        success: false,
        errorMessage: AuthConfig.notConfiguredMessage,
      );
    }
    // Start waking the API while the account picker is open.
    final serverWarmUp = ApiClient.warmUp();
    try {
      debugPrint('[GoogleAuthService] Initiating Google Sign-In flow...');

      GoogleSignInAccount? account;
      String? nativeError;
      try {
        account = await _signInClient.signIn();
      } catch (nativeErr) {
        nativeError = nativeErr.toString();
        debugPrint('[GoogleAuthService] Native GoogleSignIn error: $nativeErr');
      }

      if (account == null) {
        if (nativeError != null) {
          // On Web, if GIS native popup encountered an issue (e.g. third-party cookie/popup block or origin issue),
          // attempt browser OAuth redirect via Supabase.
          if (kIsWeb && AdoptMatchBackend.isInitialized) {
            try {
              debugPrint('[GoogleAuthService] Web native popup failed ($nativeError). Falling back to Supabase browser OAuth redirect...');
              final redirected = await Supabase.instance.client.auth.signInWithOAuth(
                OAuthProvider.google,
              );
              if (redirected) {
                return const GoogleAuthResult(
                  success: true,
                  wasCancelled: false,
                );
              }
            } catch (oauthErr) {
              debugPrint('[GoogleAuthService] Supabase OAuth redirect fallback failed: $oauthErr');
            }
          }

          String userFriendlyMsg = nativeError;
          if (nativeError.contains('ApiException: 10') ||
              nativeError.contains('DEVELOPER_ERROR')) {
            userFriendlyMsg =
                'Google Sign-In configuration error (ApiException 10). Register this '
                'build\'s SHA-1 (88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B) '
                'for package com.adoptmatch.adoptmatch in Google Cloud Console. See docs/AUTH_SETUP.md.';
          } else if (nativeError.contains('ApiException: 12500')) {
            userFriendlyMsg =
                'Google Sign-In configuration error (ApiException 12500). Please check '
                'Google Cloud OAuth consent screen settings and support email.';
          } else if (nativeError.contains('ApiException: 7') ||
              nativeError.contains('NETWORK_ERROR')) {
            userFriendlyMsg =
                'Network error contacting Google Play Services. Please verify internet connectivity.';
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
      GoogleSignInAuthentication? authHeaders;

      try {
        authHeaders = await account.authentication;
        idToken = authHeaders.idToken;
      } catch (tokenErr) {
        debugPrint('[GoogleAuthService] Token retrieval error: $tokenErr');
      }

      // Web fallback: silent re-auth attempt if idToken was omitted by GIS token client
      if (kIsWeb && (idToken == null || idToken.isEmpty)) {
        try {
          final silentAccount = await _signInClient.signInSilently(reAuthenticate: true);
          if (silentAccount != null) {
            authHeaders = await silentAccount.authentication;
            idToken = authHeaders.idToken;
          }
        } catch (_) {}
      }

      if (idToken == null || idToken.isEmpty) {
        // On Web with Supabase initialized: seamlessly trigger browser OAuth redirect flow
        if (kIsWeb && AdoptMatchBackend.isInitialized) {
          try {
            debugPrint('[GoogleAuthService] Web fallback to Supabase signInWithOAuth');
            final redirected = await Supabase.instance.client.auth.signInWithOAuth(
              OAuthProvider.google,
            );
            if (redirected) {
              return const GoogleAuthResult(
                success: true,
                wasCancelled: false,
              );
            }
          } catch (oauthErr) {
            debugPrint('[GoogleAuthService] Supabase OAuth redirect failed: $oauthErr');
            return GoogleAuthResult(
              success: false,
              errorMessage: 'Google Web OAuth initiation failed: $oauthErr',
            );
          }
        }

        final platformDetail = kIsWeb
            ? 'Web origin is not authorized in Google Cloud Console, or the browser blocked cookies/popups.'
            : 'SHA-1 fingerprint (88:60:0E:C9:44:D9:F7:FE:5B:DC:53:74:3C:BA:B1:25:32:0C:09:7B) for com.adoptmatch.adoptmatch is not registered in Google Cloud Console.';
        return GoogleAuthResult(
          success: false,
          errorMessage: 'Google did not return an ID token. $platformDetail See docs/AUTH_SETUP.md.',
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

      // Sign in via Supabase Auth (or fallback to test mock)
      if (AdoptMatchBackend.isInitialized) {
        try {
          await AdoptMatchBackend.instance.signInWithGoogle(
            idToken: idToken,
            accessToken: authHeaders?.accessToken,
          );
          var profile = await AdoptMatchBackend.instance.myProfile();
          if (profile == null) {
            await Future.delayed(const Duration(milliseconds: 250));
            profile = await AdoptMatchBackend.instance.myProfile();
          }

          Map<String, dynamic> sub = {};
          try {
            sub = await AdoptMatchBackend.instance.mySubscription();
          } catch (_) {}

          final sbUser = Supabase.instance.client.auth.currentUser;
          if (profile != null) {
            userProfile = AuthRepository.userFromSupabase(profile, sub);
            final created = sbUser?.createdAt;
            final updated = sbUser?.updatedAt;
            isNewUser = created != null && created == updated;
          } else if (sbUser != null) {
            // Profile trigger might have a slight replica lag, construct from auth metadata
            userProfile = UserProfile(
              id: sbUser.id,
              name: userName,
              email: sbUser.email ?? userEmail,
              phone: sbUser.phone ?? '',
              role: UserRole.adopter,
              avatarUrl: userPhoto,
              googlePhotoUrl: userPhoto,
              location: 'Dhaka, Bangladesh',
              bio: 'Animal advocate & pet rescuer',
              preferredPetType: 'All Pets',
              isVerified: true,
            );
          }

          final currentSession = Supabase.instance.client.auth.currentSession;
          if (currentSession != null && currentSession.accessToken.isNotEmpty) {
            await SecureStorageService.instance.saveAuthToken(currentSession.accessToken);
            await ApiClient.saveToken(currentSession.accessToken);
          }

          if (userProfile == null) {
            backendError =
                'Google verified your account, but the AdoptMatch server did not return a profile. Please try again.';
          }
        } on AdoptMatchException catch (backendErr) {
          backendError = backendErr.message;
          debugPrint('[GoogleAuthService] Supabase sign-in notice: $backendErr');
        } catch (backendErr) {
          backendError = describeNetworkFailure(
            backendErr,
            fallback: 'The AdoptMatch server could not complete the sign-in. Please try again.',
          );
          debugPrint('[GoogleAuthService] Supabase sign-in failed: $backendErr');
        }
      } else {
        try {
          // Bounded: the request below has its own 60s ceiling.
          await serverWarmUp.timeout(const Duration(seconds: 30), onTimeout: () {});
          final response = await _apiClient.dio.post('/auth/google', data: {
            'id_token': idToken,
            'idToken': idToken,
            'device_name': 'flutter_google',
          });

          final data = response.data;
          if (data is Map) {
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

            if (u is Map) {
              userProfile = UserProfile(
                id: u['id']?.toString() ?? googleId,
                name: u['name']?.toString() ?? userName,
                email: u['email']?.toString() ?? userEmail,
                phone: u['phone']?.toString() ?? '',
                role: UserRole.fromCode(u['role']?.toString()),
                avatarUrl: u['avatar']?.toString() ?? userPhoto,
                googlePhotoUrl: userPhoto,
                location: u['location']?.toString() ?? 'Dhaka, Bangladesh',
                bio: u['bio']?.toString() ?? 'Animal advocate & pet rescuer',
                preferredPetType: 'All Pets',
                isVerified: true,
              );
            }
          }
          if (userProfile == null) {
            backendError =
                'Google verified your account, but the AdoptMatch server did not return a profile. Please try again.';
          }
        } on DioException catch (backendErr) {
          backendError = describeNetworkFailure(
            backendErr,
            fallback: 'The AdoptMatch server rejected the sign-in. Please try again.',
          );
          debugPrint('[GoogleAuthService] Backend sync failed: $backendErr');
        } catch (backendErr) {
          backendError = describeNetworkFailure(
            backendErr,
            fallback: 'The AdoptMatch server could not complete the sign-in. Please try again.',
          );
          debugPrint('[GoogleAuthService] Backend sync failed: $backendErr');
        }
      }

      // Fail closed: without a server-issued session there is no signed-in user.
      if (userProfile == null) {
        return GoogleAuthResult(
          success: false,
          errorMessage: backendError ??
              'Google verified your account, but the AdoptMatch server did not issue a session. Please try again.',
        );
      }

      // Verify active session based on active backend architecture
      if (AdoptMatchBackend.isInitialized) {
        final currentSession = Supabase.instance.client.auth.currentSession;
        if (currentSession == null || currentSession.accessToken.isEmpty) {
          return const GoogleAuthResult(
            success: false,
            errorMessage:
                'The server did not return a session token. Please sign in again.',
          );
        }
      } else {
        final sessionToken = await SecureStorageService.instance.getAuthToken();
        if (sessionToken == null || sessionToken.isEmpty) {
          return const GoogleAuthResult(
            success: false,
            errorMessage:
                'The server did not return a session token. Please sign in again.',
          );
        }
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
      await _signInClient.signOut().timeout(
        const Duration(milliseconds: 300),
        onTimeout: () => null,
      );
    } catch (_) {}

    if (AdoptMatchBackend.isInitialized) {
      try {
        await AdoptMatchBackend.instance.signOut();
      } catch (_) {}
    }

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
