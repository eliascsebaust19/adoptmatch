import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/config/auth_config.dart';
import 'package:adoptmatch/core/services/google_auth_service.dart';
import '../helpers/secure_storage_mock.dart';

class MockGoogleSignIn extends Mock implements GoogleSignIn {}
class MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}
class MockGoogleSignInAuthentication extends Mock implements GoogleSignInAuthentication {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockGoogleSignIn mockSignIn;
  late MockGoogleSignInAccount mockAccount;
  late MockGoogleSignInAuthentication mockAuth;

  setUp(() async {
    await installSecureStorageMock();
    mockSignIn = MockGoogleSignIn();
    mockAccount = MockGoogleSignInAccount();
    mockAuth = MockGoogleSignInAuthentication();
    GoogleAuthService.mockGoogleSignIn = mockSignIn;

    SharedPreferences.setMockInitialValues({
      'cached_user_id': 'g-123',
      'cached_user_email': 'test@gmail.com',
      'cached_user_name': 'Test Google User',
      'cached_user_photo': 'https://example.com/photo.jpg',
      'cached_user_role': 'USER',
    });
  });

  tearDown(() {
    GoogleAuthService.mockGoogleSignIn = null;
  });

  group('GoogleAuthService & AuthConfig Tests', () {
    test('signOut clears cached user session and auth token safely', () async {
      when(() => mockSignIn.signOut()).thenAnswer((_) async => null);

      await GoogleAuthService.signOut();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('auth_token'), isNull);
      expect(prefs.getString('cached_user_id'), isNull);
      expect(prefs.getString('cached_user_email'), isNull);
    });

    test('AuthConfig provides valid web client ID without leaking secrets', () {
      expect(AuthConfig.isGoogleConfigured, isTrue);
      expect(AuthConfig.googleWebClientId, contains('apps.googleusercontent.com'));
      expect(AuthConfig.googleWebClientId, contains('94403915199'));
      expect(AuthConfig.googleWebClientId, isNot(contains('GOCSPX')));
    });

    test('AuthConfig missingIdTokenMessage contains SHA-1 and web origin guidance', () {
      final msg = AuthConfig.missingIdTokenMessage;
      expect(msg, contains('SHA-1'));
      expect(msg, contains('GOOGLE_CLIENT_ID'));
      expect(msg, contains('docs/AUTH_SETUP.md'));
    });

    test('GoogleAuthService.signIn() returns wasCancelled when user closes dialog', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => null);

      final result = await GoogleAuthService.signIn();

      expect(result.success, isFalse);
      expect(result.wasCancelled, isTrue);
      expect(result.errorMessage, contains('cancelled'));
      expect(result.user, isNull);
    });

    test('GoogleAuthService.signIn() reports ApiException 10 with SHA-1 guidance', () async {
      when(() => mockSignIn.signIn()).thenThrow(Exception('PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10:, null, null)'));

      final result = await GoogleAuthService.signIn();

      expect(result.success, isFalse);
      expect(result.wasCancelled, isFalse);
      expect(result.errorMessage, contains('ApiException 10'));
      expect(result.errorMessage, contains('com.adoptmatch.adoptmatch'));
      expect(result.user, isNull);
    });

    test('GoogleAuthService.signIn() fails closed when ID token retrieval returns null', () async {
      when(() => mockSignIn.signIn()).thenAnswer((_) async => mockAccount);
      when(() => mockSignIn.signInSilently(reAuthenticate: true)).thenAnswer((_) async => null);
      when(() => mockAccount.authentication).thenAnswer((_) async => mockAuth);
      when(() => mockAuth.idToken).thenReturn(null);
      when(() => mockAuth.accessToken).thenReturn(null);

      final result = await GoogleAuthService.signIn();

      expect(result.success, isFalse);
      expect(result.user, isNull);
      expect(result.errorMessage, contains('Google did not return an ID token'));
      expect(result.errorMessage, contains('docs/AUTH_SETUP.md'));
    });
  });
}
