import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../storage/secure_storage_service.dart';
import '../supabase/adoptmatch_supabase.dart';
import 'google_auth_service.dart';

/// Supabase Authentication & Multi-Factor Email OTP Service
///
/// - Role: Manages Google OAuth bypass and 6-digit Email OTP guard for credentials.
/// - Design Pattern: Service Gateway / Singleton Pattern.
/// - Backend Integration: Supabase GoTrue Auth API (`signInWithOAuth`, `signInWithOtp`, `verifyOTP`).
class SupabaseAuthService {
  SupabaseAuthService._();
  static final SupabaseAuthService instance = SupabaseAuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  /// Flow A: Direct Google Sign-In (No OTP Needed).
  /// Google accounts are pre-verified, so this bypasses OTP and completes session setup.
  Future<GoogleAuthResult> signInWithGoogle() async {
    return await GoogleAuthService.signIn();
  }

  /// Flow B Step 1 & 2: Validates email + password credentials and sends 6-digit OTP.
  /// Does NOT persist the session; the user must verify the OTP code before full login.
  Future<void> loginWithPasswordAndSendOtp({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!AdoptMatchBackend.isInitialized) {
      throw Exception('Supabase is not initialized. Please check network connection.');
    }

    // 1. Verify credentials with Supabase password sign-in
    try {
      final res = await _client.auth.signInWithPassword(
        email: cleanEmail,
        password: password,
      );

      if (res.user == null) {
        throw const AuthException('Invalid user credentials.');
      }
    } on AuthException catch (e) {
      throw Exception(_parseAuthException(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Sign-in failed. Please verify your email and password.');
    }

    // 2. Immediately sign out locally so session is NOT active until OTP verification
    try {
      await _client.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      debugPrint('[SupabaseAuthService] Local sign-out error (safe to ignore): $e');
    }

    // 3. Dispatch 6-digit OTP code to the user's Gmail/Email inbox
    try {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      throw Exception(_parseAuthException(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Could not dispatch OTP code to $cleanEmail. Please try again.');
    }
  }

  /// Resends the 6-digit OTP code to the specified email address
  Future<void> resendEmailOtp(String email) async {
    final cleanEmail = email.trim().toLowerCase();

    if (!AdoptMatchBackend.isInitialized) {
      throw Exception('Supabase is not initialized.');
    }

    try {
      await _client.auth.signInWithOtp(
        email: cleanEmail,
        shouldCreateUser: false,
      );
    } on AuthException catch (e) {
      throw Exception(_parseAuthException(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Failed to resend verification code. Please wait and try again.');
    }
  }

  /// Flow B Step 3: Verifies the 6-digit Email OTP and returns the authorized session.
  Future<AuthResponse> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanToken = token.trim();

    if (!AdoptMatchBackend.isInitialized) {
      throw Exception('Supabase is not initialized.');
    }

    try {
      final res = await _client.auth.verifyOTP(
        email: cleanEmail,
        token: cleanToken,
        type: OtpType.email,
      );

      if (res.session == null || res.user == null) {
        throw const AuthException('Verification failed: No active session created.');
      }

      // Persist auth token in secure storage
      final accessToken = res.session!.accessToken;
      await SecureStorageService.instance.saveAuthToken(accessToken);

      return res;
    } on AuthException catch (e) {
      throw Exception(_parseAuthException(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Invalid or expired verification code. Please try again.');
    }
  }

  /// Maps Supabase AuthException into human-friendly error messages
  String _parseAuthException(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') || msg.contains('invalid credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Email address is not confirmed. Please verify your email first.';
    }
    if (msg.contains('token has expired') || msg.contains('otp expired')) {
      return 'Verification code has expired. Please tap Resend Code.';
    }
    if (msg.contains('invalid token') || msg.contains('token is invalid') || msg.contains('invalid otp')) {
      return 'Invalid 6-digit verification code. Please check your inbox and try again.';
    }
    if (msg.contains('rate limit') || msg.contains('too many requests')) {
      return 'Too many attempts. Please wait 60 seconds before requesting another code.';
    }
    if (msg.contains('user not found')) {
      return 'No account found with this email address.';
    }
    if (msg.contains('signups not allowed for otp')) {
      return 'OTP sign-in is not permitted for unregistered accounts. Please sign up first.';
    }
    return e.message;
  }
}
