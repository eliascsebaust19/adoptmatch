import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../../features/auth/bloc/auth_bloc.dart';

class GoogleAuthResult {
  final bool success;
  final UserProfile? user;
  final String? errorMessage;
  final bool wasCancelled;

  const GoogleAuthResult({
    required this.success,
    this.user,
    this.errorMessage,
    this.wasCancelled = false,
  });
}

class GoogleAuthService {
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '94403915199-50ug4q14m66gn3pjmhh441givdf0etie.apps.googleusercontent.com',
  );

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'http://localhost:5000',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: webClientId,
  );

  /// Performs Google Sign-In with resilience:
  /// 1. Tries Native GoogleSignIn (Android/iOS Account Picker)
  /// 2. If user completes sign-in, syncs with Backend (/api/v1/auth/google) or Supabase
  /// 3. If Supabase throws 'provider is not enabled', handles gracefully with informative prompt
  static Future<GoogleAuthResult> signIn() async {
    try {
      debugPrint('[GoogleAuthService] Initiating Google Sign-In flow...');

      // 1. Trigger Google native account picker
      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } catch (nativeErr) {
        debugPrint('[GoogleAuthService] Native GoogleSignIn error: $nativeErr');
        // If native dialog fails or environment doesn't have play services, fallback to Supabase OAuth
        return await _fallbackSupabaseOAuth();
      }

      // 2. Handle user cancelling the account picker dialog
      if (account == null) {
        debugPrint('[GoogleAuthService] User cancelled Google sign-in dialog.');
        return const GoogleAuthResult(success: false, wasCancelled: true);
      }

      final authHeaders = await account.authentication;
      final idToken = authHeaders.idToken;
      final accessToken = authHeaders.accessToken;

      debugPrint('[GoogleAuthService] Obtained Google account: ${account.email}');

      // Sync Supabase Auth session with Google ID token
      if (idToken != null && SupabaseService.isInitialized) {
        try {
          await SupabaseService.auth.signInWithIdToken(
            provider: OAuthProvider.google,
            idToken: idToken,
            accessToken: accessToken,
          );
          debugPrint('[GoogleAuthService] Supabase session synced via ID token.');
        } catch (sbErr) {
          debugPrint('[GoogleAuthService] Supabase ID token sync notice: $sbErr');
        }
      }

      // 3. Sync with Backend API (/api/v1/auth/google)
      UserProfile? userProfile;
      try {
        final res = await http.post(
          Uri.parse('$backendBaseUrl/api/v1/auth/google'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'idToken': idToken,
            'accessToken': accessToken,
            'profile': {
              'id': account.id,
              'email': account.email,
              'name': account.displayName ?? account.email.split('@')[0],
              'photoUrl': account.photoUrl ?? '',
            },
          }),
        ).timeout(const Duration(seconds: 4));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          final u = data['user'];
          final tokens = data['tokens'];

          // Save session token in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          if (tokens != null && tokens['accessToken'] != null) {
            await prefs.setString('auth_token', tokens['accessToken']);
          }

          userProfile = UserProfile(
            id: u['id'] ?? account.id,
            name: u['name'] ?? account.displayName ?? 'Google User',
            email: u['email'] ?? account.email,
            phone: u['phone'] ?? '',
            role: UserRole.fromCode(u['role']),
            avatarUrl: u['avatarUrl'] ?? account.photoUrl ?? '',
            googlePhotoUrl: account.photoUrl ?? '',
            location: u['location'] ?? 'Dhaka, Bangladesh',
            bio: u['bio'] ?? 'Animal advocate & pet rescuer',
            preferredPetType: u['preferredPetType'] ?? 'All Pets',
            isVerified: true,
          );
        }
      } catch (backendErr) {
        debugPrint('[GoogleAuthService] Backend sync error (continuing with local profile): $backendErr');
      }

      // If backend was unreachable, construct profile directly from verified Google account
      userProfile ??= UserProfile(
        id: 'google-${account.id}',
        name: account.displayName ?? account.email.split('@')[0],
        email: account.email,
        phone: '',
        role: UserRole.adopter,
        avatarUrl: account.photoUrl ?? '',
        googlePhotoUrl: account.photoUrl ?? '',
        location: 'Dhaka, Bangladesh',
        bio: 'Animal advocate & pet rescuer',
        preferredPetType: 'All Pets',
        isVerified: true,
      );

      // Persist user in SharedPreferences for seamless reload
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_id', userProfile.id);
      await prefs.setString('cached_user_email', userProfile.email);
      await prefs.setString('cached_user_name', userProfile.name);
      await prefs.setString('cached_user_photo', userProfile.avatarUrl);
      await prefs.setString('cached_user_role', userProfile.role.code);

      return GoogleAuthResult(success: true, user: userProfile);
    } catch (e) {
      debugPrint('[GoogleAuthService] Exception in Google Sign-In: $e');
      return GoogleAuthResult(
        success: false,
        errorMessage: _sanitizeErrorMessage(e.toString()),
      );
    }
  }

  /// Fallback to Supabase Browser OAuth if native account picker is unavailable
  static Future<GoogleAuthResult> _fallbackSupabaseOAuth() async {
    if (!SupabaseService.isInitialized) {
      return const GoogleAuthResult(
        success: false,
        errorMessage: 'Authentication service is initializing. Please try again.',
      );
    }

    try {
      await SupabaseService.signInWithGoogle();
      return const GoogleAuthResult(success: true);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('provider is not enabled') || msg.contains('unsupported provider')) {
        return const GoogleAuthResult(
          success: false,
          errorMessage:
              'Google Provider is not enabled in your Supabase project dashboard. Please enable it in Authentication -> Providers -> Google, or configure Google OAuth credentials.',
        );
      }
      return GoogleAuthResult(success: false, errorMessage: _sanitizeErrorMessage(e.toString()));
    }
  }

  /// Sign out from Google and clear local session
  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut().timeout(const Duration(milliseconds: 300), onTimeout: () => null);
    } catch (_) {}

    try {
      final prefs = await SharedPreferences.getInstance().timeout(const Duration(milliseconds: 300));
      await prefs.remove('auth_token');
      await prefs.remove('cached_user_id');
      await prefs.remove('cached_user_email');
      await prefs.remove('cached_user_name');
      await prefs.remove('cached_user_photo');
      await prefs.remove('cached_user_role');
    } catch (_) {}
  }

  static String _sanitizeErrorMessage(String raw) {
    if (raw.contains('network_error') || raw.contains('SocketException')) {
      return 'Network connection error. Please check your internet connection.';
    }
    if (raw.contains('sign_in_canceled') || raw.contains('canceled')) {
      return 'Google sign-in was cancelled.';
    }
    if (raw.contains('provider is not enabled')) {
      return 'Google OAuth provider is not enabled in your Supabase dashboard yet.';
    }
    return raw.replaceAll('Exception:', '').trim();
  }
}
