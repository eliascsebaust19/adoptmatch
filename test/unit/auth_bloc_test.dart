import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthBloc Production Hardened Auth Flow Tests', () {
    late AuthBloc authBloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state is AuthInitial in production', () {
      expect(authBloc.state, isA<AuthInitial>());
    });

    blocTest<AuthBloc, AuthState>(
      'SignUpWithEmailEvent emits [AuthLoading, Authenticated] upon successful registration',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(
        const SignUpWithEmailEvent(
          fullName: 'Nadia Rahman',
          email: 'nadia.test@gmail.com',
          password: 'password123',
        ),
      ),
      wait: const Duration(milliseconds: 800),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((state) {
          return state is Authenticated &&
              state.user.email == 'nadia.test@gmail.com' &&
              state.isNewUser == true;
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'UserConfirmedSessionEvent updates user state to verified Authenticated',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(
        const UserConfirmedSessionEvent(
          UserProfile(
            id: 'sb-usr-1',
            name: 'Confirmed User',
            email: 'confirmed@gmail.com',
            phone: '+880 1711 000000',
            isVerified: true,
          ),
        ),
      ),
      expect: () => [
        predicate<AuthState>((state) {
          return state is Authenticated &&
              state.user.email == 'confirmed@gmail.com' &&
              state.user.isVerified == true;
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'LogoutEvent emits AuthUnauthenticated and revokes session',
      build: () => AuthBloc(
        initialUser: const UserProfile(
          id: 'test-user-1',
          name: 'Test User',
          email: 'test@adoptmatch.com',
          phone: '',
        ),
      ),
      act: (bloc) => bloc.add(LogoutEvent()),
      wait: const Duration(milliseconds: 500),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'GuestLoginEvent is rejected in production',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const GuestLoginEvent()),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        predicate<AuthState>((state) {
          return state is AuthFailure &&
              state.errorMessage.contains('Guest access is disabled');
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AdminLoginWithEmailEvent with invalid credentials rejects with Access Denied',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(
        const AdminLoginWithEmailEvent(
          'unauthorized@adoptmatch.org',
          'invalidPass',
        ),
      ),
      wait: const Duration(milliseconds: 800),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((state) {
          return state is AuthFailure &&
              state.errorMessage.contains('Access Denied');
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'UpdateUserProfileEvent updates user name, phone, avatarUrl, location, and bio',
      build: () => AuthBloc(
        initialUser: const UserProfile(
          id: 'u-101',
          name: 'Initial User',
          email: 'user@example.com',
          phone: '+880 1711 000000',
        ),
      ),
      act: (bloc) => bloc.add(
        const UpdateUserProfileEvent(
          name: 'Nadia Karim',
          phone: '+880 1712 999111',
          avatarUrl: 'https://images.unsplash.com/photo-test-avatar',
          location: 'Gulshan 2, Dhaka',
          bio: 'Passionate cat adopter & foster parent',
          preferredPetType: 'Cats',
        ),
      ),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        predicate<AuthState>((state) {
          if (state is! Authenticated) return false;
          final u = state.user;
          return u.name == 'Nadia Karim' &&
              u.phone == '+880 1712 999111' &&
              u.avatarUrl == 'https://images.unsplash.com/photo-test-avatar' &&
              u.location == 'Gulshan 2, Dhaka' &&
              u.bio == 'Passionate cat adopter & foster parent' &&
              u.preferredPetType == 'Cats';
        }),
      ],
    );
  });
}
