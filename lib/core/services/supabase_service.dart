import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static const String defaultUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wgztdhabgedhkaippkpd.supabase.co',
  );

  static const String defaultAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndnenRkaGFiZ2VkaGthaXBwa3BkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI3ODAzMTksImV4cCI6MjEwODM1NjMxOX0.KolY1dw6NuDxZAt14bCcJz0NLLmMa05HHixz4TFtZMM',
  );

  static const String googleClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '94403915199-50ug4q14m66gn3pjmhh441givdf0etie.apps.googleusercontent.com',
  );

  static bool _isInitialized = false;
  static bool get isInitialized => _isInitialized;

  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: defaultUrl,
        anonKey: defaultAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        debug: kDebugMode,
      );
      _isInitialized = true;
      debugPrint('[SupabaseService] Initialized with PKCE flow successfully.');
    } catch (e) {
      debugPrint('[SupabaseService] Initialization warning: $e');
    }
  }

  static SupabaseClient get client {
    if (!_isInitialized) {
      throw StateError('Supabase has not been initialized. Call SupabaseService.initialize() first.');
    }
    return Supabase.instance.client;
  }

  static GoTrueClient get auth => client.auth;

  /// Register new user with full name, email and password
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    required String fullName,
    String emailRedirectTo = 'adoptmatch://auth-callback',
  }) async {
    try {
      final response = await auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: emailRedirectTo,
      );

      // Do NOT automatically log them into dashboard
      // Always sign out any temporary local session until email confirmation link is clicked
      if (response.session != null) {
        await auth.signOut();
      }

      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign in with email and password, enforcing email verification
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      // If user exists but email is not confirmed, block access
      if (user != null && user.emailConfirmedAt == null) {
        await auth.signOut();
        throw const AuthException('Please verify your email address before logging in.');
      }

      return response;
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('email not confirmed') ||
          e.message.toLowerCase().contains('email_not_confirmed')) {
        throw const AuthException('Please verify your email address before logging in.');
      }
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign in via Google OAuth
  static Future<bool> signInWithGoogle({
    String redirectTo = 'adoptmatch://auth-callback',
  }) async {
    try {
      return await auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Update user password
  static Future<UserResponse?> updatePassword(String newPassword) async {
    try {
      if (_isInitialized && auth.currentUser != null) {
        return await auth.updateUser(UserAttributes(password: newPassword));
      }
      return null;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      if (_isInitialized) {
        await auth.signOut();
      }
    } catch (e) {
      debugPrint('[SupabaseService] signOut error: $e');
    }
  }
}

