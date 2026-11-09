import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/auth_config.dart';

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

  static String get googleClientId => AuthConfig.googleWebClientId;

  static bool _isInitialized = false;

  /// `?code=` can only be redeemed once. Without this, a refresh of the
  /// callback URL replays a used code and shows a scary "invalid link" error
  /// even though the session is fine.
  static bool _redirectConsumed = false;

  /// Set once the user has finished the recovery flow, so later `Authenticated`
  /// emissions cannot bounce them back onto the password screen.
  static bool _recoveryHandled = false;

  static void markRecoveryHandled() => _recoveryHandled = true;

  /// True once a Supabase client exists. `main()` initializes the client, so
  /// this must not depend on [initialize] having been called: that method is
  /// only an optional convenience for tests and alternate entry points.
  static bool get isInitialized {
    if (_isInitialized) return true;
    try {
      Supabase.instance.client;
      return true;
    } catch (_) {
      return false;
    }
  }

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
    if (!isInitialized) {
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
    String? emailRedirectTo,
  }) async {
    try {
      final response = await auth.signUp(
        email: email,
        password: password,
        data: {'full_name': fullName},
        emailRedirectTo: emailRedirectTo ?? AuthConfig.emailRedirectUrl,
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
  static Future<bool> signInWithGoogle({String? redirectTo}) async {
    try {
      return await auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo ?? AuthConfig.oauthRedirectUrl,
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
      if (isInitialized && auth.currentUser != null) {
        return await auth.updateUser(UserAttributes(password: newPassword));
      }
      return null;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Completes a web OAuth / email-link round-trip.
  ///
  /// Supabase returns `?code=...` (PKCE) or `#access_token=...` on the redirect
  /// URL. Desktop and mobile are handled by the plugin; the web build is not,
  /// and a code that is never exchanged leaves the user signed out with a URL
  /// that looks successful. Returns the resulting session, or null when there
  /// is nothing to redeem.
  static Future<Session?> completeWebRedirect() async {
    if (!kIsWeb || !isInitialized) return null;
    try {
      final uri = Uri.base;
      // Two shapes exist: `origin/auth-callback?code=...` with the path URL
      // strategy, and `origin/#/auth-callback?code=...` with the default hash
      // strategy. Read the query string from both.
      final fragment = uri.fragment;
      final fragmentQuery = fragment.contains('?')
          ? fragment.substring(fragment.indexOf('?') + 1)
          : (fragment.contains('=') ? fragment : '');
      final params = <String, String>{
        ...uri.queryParameters,
        ...Uri.splitQueryString(fragmentQuery),
      };

      if (params['error_description'] != null || params['error'] != null) {
        throw AuthException(
          params['error_description'] ?? params['error'] ?? 'Sign-in failed.',
        );
      }

      if (params.containsKey('code') && !_redirectConsumed) {
        // The SDK reads the same URL, stores the verifier and redeems the code.
        await auth.getSessionFromUrl(uri);
        _redirectConsumed = true;
      } else if (params['access_token'] != null &&
          params['refresh_token'] != null) {
        await auth.setSession(params['refresh_token']!);
      } else {
        return auth.currentSession;
      }

      return auth.currentSession;
    } on AuthException catch (e) {
      debugPrint('[SupabaseService] Redirect exchange failed: ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[SupabaseService] Redirect exchange error: $e');
      return null;
    }
  }

  /// Turns a `?type=recovery` / `#type=recovery` deep link into the route the
  /// app should open. Null when the link is an ordinary sign-in.
  static String? get pendingRecoveryRoute {
    if (_recoveryHandled) return null;
    final fragment = Uri.base.fragment;
    final location = fragment.isNotEmpty ? fragment : Uri.base.query;
    return location.contains('type=recovery') ? '/auth/reset-password' : null;
  }

  /// Sign out
  static Future<void> signOut() async {
    try {
      if (isInitialized) {
        await auth.signOut();
      }
    } catch (e) {
      debugPrint('[SupabaseService] signOut error: $e');
    }
  }
}

