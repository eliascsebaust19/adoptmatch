/// Single source of truth for authentication configuration.
///
/// Every layer (Google Sign-In, Supabase, Laravel/Node token exchange) must use
/// the SAME Google **Web** OAuth client ID. On Android/iOS it is passed as
/// `serverClientId` so the returned ID token has `aud = <web client id>`, which is
/// exactly what the backends verify. A mismatch produces HTTP 401.
///
/// Override at build time:
///   flutter run --dart-define=GOOGLE_CLIENT_ID=<web-client-id>
///   flutter build apk --dart-define=GOOGLE_CLIENT_ID=<web-client-id> \
///     --dart-define=GOOGLE_IOS_CLIENT_ID=<ios-client-id>
class AuthConfig {
  const AuthConfig._();

  /// Web OAuth client ID. Used as `clientId` on web and `serverClientId` on mobile.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue:
        '94403915199-50ug4q14m66gn3pjmhh441givdf0etie.apps.googleusercontent.com',
  );

  /// iOS OAuth client ID (required for the iOS URL scheme; see ios/Flutter/GoogleAuth.xcconfig).
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue: '',
  );

  static bool get isGoogleConfigured => googleWebClientId.trim().isNotEmpty;

  /// Actionable message when Google did not return an ID token. This is almost
  /// always a platform registration problem, not a server problem.
  static const String missingIdTokenMessage =
      'Google did not return an ID token. Check that GOOGLE_CLIENT_ID is the Web '
      'OAuth client ID, that this build\'s SHA-1 (Android) or bundle ID + URL '
      'scheme (iOS) is registered in Google Cloud Console, and that the web '
      'origin is authorised. See docs/AUTH_SETUP.md.';

  static const String notConfiguredMessage =
      'Google sign-in is not configured in this build. Rebuild with '
      '--dart-define=GOOGLE_CLIENT_ID=<web-client-id>. See docs/AUTH_SETUP.md.';
}
