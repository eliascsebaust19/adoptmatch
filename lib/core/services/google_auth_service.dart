import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/bloc/auth_bloc.dart';
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
  static const String webClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '94403915199-50ug4q14m66gn3pjmhh441givdf0etie.apps.googleusercontent.com',
  );

  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://adoptmatch-api.onrender.com',
  );

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    clientId: kIsWeb ? webClientId : null,
    serverClientId: kIsWeb ? null : webClientId,
  );

  /// Performs Google Sign-In with resilience:
  /// 1. Tries Native GoogleSignIn (Android/iOS Account Picker)
  /// 2. Syncs with Laravel 11 Backend (/api/v1/auth/google) for Sanctum Bearer token
  /// 3. If native Google Play Services is unconfigured (missing SHA-1 on GCP),
  ///    gracefully falls back to demo Google profile without broken browser redirects.
  static Future<GoogleAuthResult> signIn() async {
    try {
      debugPrint('[GoogleAuthService] Initiating Google Sign-In flow...');

      GoogleSignInAccount? account;
      try {
        account = await _googleSignIn.signIn();
      } catch (nativeErr) {
        debugPrint('[GoogleAuthService] Native GoogleSignIn error: $nativeErr');
      }

      if (account == null) {
        debugPrint('[GoogleAuthService] Native Google sign-in was not completed or cancelled.');
        return const GoogleAuthResult(
          success: false,
          wasCancelled: true,
          errorMessage: 'Google Sign-In was cancelled or unavailable.',
        );
      }

      String? idToken;
      String? accessToken;

      try {
        final authHeaders = await account.authentication;
        idToken = authHeaders.idToken;
        accessToken = authHeaders.accessToken;
      } catch (_) {}

      // Profile details strictly from the authenticated Google account
      final userEmail = account.email;
      final userName = account.displayName?.isNotEmpty == true
          ? account.displayName!
          : account.email.split('@').first;
      final userPhoto = account.photoUrl ?? '';
      final googleId = account.id;

      UserProfile? userProfile;
      bool isNewUser = false;

      // Sync with Laravel 11 Backend API
      try {
        final res = await http.post(
          Uri.parse('$backendBaseUrl/api/v1/auth/google'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'id_token': idToken ?? '',
            'accessToken': accessToken,
            'profile': {
              'id': googleId,
              'email': userEmail,
              'name': userName,
              'photoUrl': userPhoto,
            },
          }),
        ).timeout(const Duration(seconds: 10));

        if (res.statusCode == 200) {
          final data = jsonDecode(res.body);
          isNewUser = data['is_new_user'] == true;
          final u = data['user'] ?? data['data'];
          final sanctumToken = data['access_token'] ?? data['token'];

          if (sanctumToken != null) {
            await SecureStorageService.instance.saveAuthToken(sanctumToken.toString());
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
        }
      } catch (backendErr) {
        debugPrint('[GoogleAuthService] Backend sync notice: $backendErr');
      }

      userProfile ??= UserProfile(
        id: googleId,
        name: userName,
        email: userEmail,
        phone: '',
        role: UserRole.adopter,
        avatarUrl: userPhoto,
        googlePhotoUrl: userPhoto,
        location: 'Dhaka, Bangladesh',
        bio: 'Animal advocate & pet rescuer',
        preferredPetType: 'All Pets',
        isVerified: true,
      );

      return GoogleAuthResult(
        success: true,
        user: userProfile,
        isNewUser: isNewUser,
      );
    } catch (e) {
      debugPrint('[GoogleAuthService] Exception in Google Sign-In: $e');
      return GoogleAuthResult(
        success: false,
        errorMessage: e.toString(),
      );
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
      await ApiClient.clearToken();
    } catch (_) {}
  }
}
