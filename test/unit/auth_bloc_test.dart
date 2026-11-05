import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthBloc Supabase Auth Flow Tests', () {
    late AuthBloc authBloc;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authBloc = AuthBloc();
    });

    tearDown(() {
      authBloc.close();
    });

    test('initial state has default guest/adopter user', () {
      expect(authBloc.state, isA<Authenticated>());
    });

    blocTest<AuthBloc, AuthState>(
      'SignUpWithEmailEvent emits [AuthLoading, AuthSignUpConfirmationPending] and does NOT auto login',
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
          return state is AuthSignUpConfirmationPending &&
              state.email == 'nadia.test@gmail.com' &&
              state.message.contains(
                'confirmation email has been sent to your Gmail',
              );
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
      'LogoutEvent emits AuthUnauthenticated',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(LogoutEvent()),
      wait: const Duration(milliseconds: 500),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'GuestLoginEvent emits [AuthLoading, Authenticated] with guest role',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const GuestLoginEvent()),
      wait: const Duration(milliseconds: 500),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((state) {
          return state is Authenticated &&
              state.user.role == UserRole.guest &&
              state.user.role.isGuest == true &&
              state.user.role.isConsumer == true &&
              state.user.role.hasAdminAccess == false;
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AdminLoginWithEmailEvent with super admin credentials grants SUPER_ADMIN role',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const AdminLoginWithEmailEvent('superadmin@adoptmatch.org', 'adminSecure2026!')),
      wait: const Duration(milliseconds: 800),
      expect: () => [
        isA<AuthLoading>(),
        predicate<AuthState>((state) {
          return state is Authenticated &&
              state.user.role == UserRole.superAdmin &&
              state.user.role.isAdmin == true;
        }),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'AdminLoginWithEmailEvent with non-admin credentials rejects with Access Denied',
      build: () => AuthBloc(),
      act: (bloc) => bloc.add(const AdminLoginWithEmailEvent('regular.user@gmail.com', 'password123')),
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
      build: () => AuthBloc(),
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
