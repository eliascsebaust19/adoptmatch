import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:adoptmatch/core/services/supabase_auth_service.dart';
import 'package:adoptmatch/features/auth/screens/email_otp_verification_screen.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';
import 'package:adoptmatch/features/auth/repositories/auth_repository.dart';
import 'package:adoptmatch/core/network/api_client.dart';
import 'package:adoptmatch/core/services/api_auth_service.dart';
import '../helpers/secure_storage_mock.dart';

void main() {
  setUp(() async {
    await installSecureStorageMock();
  });

  group('SupabaseAuthService Tests', () {
    test('SupabaseAuthService instance is available as singleton', () {
      final s1 = SupabaseAuthService.instance;
      final s2 = SupabaseAuthService.instance;
      expect(identical(s1, s2), isTrue);
    });

    test('loginWithPasswordAndSendOtp validates email parameter', () async {
      final service = SupabaseAuthService.instance;
      // When Supabase is not initialized in offline test mode, fails closed
      await expectLater(
        service.loginWithPasswordAndSendOtp(
          email: 'test@example.com',
          password: 'password123',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('verifyEmailOtp validates token and email', () async {
      final service = SupabaseAuthService.instance;
      await expectLater(
        service.verifyEmailOtp(
          email: 'test@example.com',
          token: '123456',
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('VerifyOtpScreen Widget Tests', () {
    testWidgets('renders email verification title, 6 PIN boxes, and resend countdown', (tester) async {
      final authRepo = AuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        laravelAuthService: ApiAuthService(
          apiClient: ApiClient(baseUrl: 'https://api.example.test/api/v1'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const VerifyOtpScreen(email: 'rescuer@adoptmatch.org'),
          ),
        ),
      );

      await tester.pump();

      // Check header and email
      expect(find.text('Email Verification'), findsOneWidget);
      expect(find.text('rescuer@adoptmatch.org'), findsOneWidget);

      // Check 6 PIN TextFields
      expect(find.byType(TextField), findsNWidgets(6));

      // Check Verify button
      expect(find.text('Verify & Continue'), findsOneWidget);

      // Check Resend timer presence
      expect(find.textContaining('Resend in'), findsOneWidget);

      // Check Security badge
      expect(find.text('Secured by Supabase Email OTP Guard'), findsOneWidget);
    });

    testWidgets('entering code updates textfields', (tester) async {
      final authRepo = AuthRepository();
      final authBloc = AuthBloc(
        authRepository: authRepo,
        laravelAuthService: ApiAuthService(
          apiClient: ApiClient(baseUrl: 'https://api.example.test/api/v1'),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const VerifyOtpScreen(email: 'user@adoptmatch.org'),
          ),
        ),
      );

      await tester.pump();

      // Enter a digit in the first box
      await tester.enterText(find.byType(TextField).first, '5');
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });
  });
}
