import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';
import 'package:adoptmatch/features/auth/repositories/auth_repository.dart';
import 'package:adoptmatch/core/services/laravel_auth_service.dart';
import '../helpers/secure_storage_mock.dart';

class MockAuthRepository extends Mock implements AuthRepository {}
class MockLaravelAuthService extends Mock implements LaravelAuthService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository auth;
  late MockLaravelAuthService laravel;

  setUp(() async {
    await installSecureStorageMock();
    SharedPreferences.setMockInitialValues({});
    auth = MockAuthRepository(); laravel = MockLaravelAuthService();
    when(() => auth.logout()).thenAnswer((_) async {});
  });

  blocTest<AuthBloc, AuthState>(
    'signup authenticates only after a server token and profile',
    build: () {
      when(() => laravel.register(name: any(named: 'name'), email: any(named: 'email'),
        password: any(named: 'password'), role: any(named: 'role'), phone: any(named: 'phone')))
        .thenAnswer((_) async => {'status': 'success', 'access_token': 'server-token',
          'user': {'id': '1', 'name': 'Nadia', 'email': 'nadia@example.test', 'role': 'adopter'}});
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) => bloc.add(const SignUpWithEmailEvent(fullName: 'Nadia',
      email: 'nadia@example.test', password: 'password123')),
    expect: () => [isA<AuthLoading>(), isA<Authenticated>()
      .having((s) => s.user.email, 'email', 'nadia@example.test')
      .having((s) => s.isNewUser, 'isNewUser', true)],
  );

  blocTest<AuthBloc, AuthState>(
    'signup failure never creates a local authenticated session',
    build: () {
      when(() => laravel.register(name: any(named: 'name'), email: any(named: 'email'),
        password: any(named: 'password'), role: any(named: 'role'), phone: any(named: 'phone')))
        .thenThrow(Exception('server unavailable'));
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) => bloc.add(const SignUpWithEmailEvent(fullName: 'Nadia',
      email: 'nadia@example.test', password: 'password123')),
    expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
  );

  blocTest<AuthBloc, AuthState>(
    'admin login rejects a non-privileged server account',
    build: () {
      when(() => auth.loginWithEmail(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const UserProfile(id: '1', name: 'User',
          email: 'user@example.test', phone: '', role: UserRole.adopter));
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) => bloc.add(const AdminLoginWithEmailEvent('user@example.test', 'password')),
    expect: () => [isA<AuthLoading>(), isA<AuthFailure>()
      .having((s) => s.errorMessage, 'message', contains('Access Denied'))],
  );

  blocTest<AuthBloc, AuthState>(
    'OTP request reports provider failure instead of pretending delivery',
    build: () {
      when(() => laravel.requestPhoneOtp(any())).thenThrow(Exception('not configured'));
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) => bloc.add(const RequestPhoneOtpEvent('01700000000')),
    expect: () => [isA<AuthLoading>(), isA<AuthFailure>()],
  );

  blocTest<AuthBloc, AuthState>(
    'guest login remains disabled',
    build: () => AuthBloc(authRepository: auth, laravelAuthService: laravel),
    act: (bloc) => bloc.add(const GuestLoginEvent()),
    expect: () => [isA<AuthFailure>().having((s) => s.errorMessage, 'message', contains('Guest access is disabled'))],
  );

  blocTest<AuthBloc, AuthState>(
    'password change succeeds only when the server confirms it',
    build: () {
      when(() => auth.loginWithEmail(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const UserProfile(id: '1', name: 'Nadia',
          email: 'nadia@example.test', phone: '', role: UserRole.adopter));
      when(() => laravel.changePassword(currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'))).thenAnswer((_) async {});
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) async {
      bloc.add(const LoginWithEmailEvent('nadia@example.test', 'old-password'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChangePasswordEvent(currentPassword: 'old-password', newPassword: 'new-password-1'));
    },
    expect: () => [isA<AuthLoading>(), isA<Authenticated>(), isA<AuthLoading>(),
      isA<AuthPasswordChanged>(), isA<Authenticated>()],
  );

  blocTest<AuthBloc, AuthState>(
    'password change failure never reports success',
    build: () {
      when(() => auth.loginWithEmail(email: any(named: 'email'), password: any(named: 'password')))
        .thenAnswer((_) async => const UserProfile(id: '1', name: 'Nadia',
          email: 'nadia@example.test', phone: '', role: UserRole.adopter));
      when(() => laravel.changePassword(currentPassword: any(named: 'currentPassword'),
        newPassword: any(named: 'newPassword'))).thenThrow(Exception('wrong current password'));
      return AuthBloc(authRepository: auth, laravelAuthService: laravel);
    },
    act: (bloc) async {
      bloc.add(const LoginWithEmailEvent('nadia@example.test', 'old-password'));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const ChangePasswordEvent(currentPassword: 'wrong', newPassword: 'new-password-1'));
    },
    expect: () => [isA<AuthLoading>(), isA<Authenticated>(), isA<AuthLoading>(),
      isA<AuthFailure>(), isA<Authenticated>()],
  );
}
