import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/services/local_storage_service.dart';
import 'package:adoptmatch/core/services/notification_service.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';
import 'package:adoptmatch/features/onboarding/screens/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Onboarding & First-Time Welcome Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      LocalStorageService.instance.resetForTesting();
    });

    test('LocalStorageService defaults hasSeenOnboarding to false and persists true', () async {
      final storage = LocalStorageService.instance;
      expect(await storage.loadHasSeenOnboarding(), isFalse);
      expect(storage.hasSeenOnboarding, isFalse);

      await storage.saveHasSeenOnboarding(true);
      expect(await storage.loadHasSeenOnboarding(), isTrue);
      expect(storage.hasSeenOnboarding, isTrue);
    });

    test('Authenticated state correctly preserves and compares isNewUser flag', () {
      const user = UserProfile(
        id: 'user_1',
        name: 'Test Adopter',
        email: 'test@example.com',
        phone: '+880 1700 000000',
        role: UserRole.adopter,
      );

      const stateNew = Authenticated(user, isNewUser: true);
      const stateReturning = Authenticated(user, isNewUser: false);

      expect(stateNew.isNewUser, isTrue);
      expect(stateReturning.isNewUser, isFalse);
      expect(stateNew, isNot(equals(stateReturning)));
    });

    test('NotificationService showNotification executes without error', () async {
      await expectLater(
        NotificationService.showNotification(
          title: 'Welcome to AdoptMatch! 🐾',
          body: 'Your account has been created successfully.',
        ),
        completes,
      );
    });

    testWidgets('OnboardingScreen renders first carousel card and controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: OnboardingScreen(),
        ),
      );

      // Verify Card 1 title and content
      expect(find.text('Swipe to Match Pets 🐾'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next ➔'), findsOneWidget);
      expect(find.text('AdoptMatch'), findsOneWidget);

      // Tap Next to advance to Card 2
      await tester.tap(find.text('Next ➔'));
      await tester.pumpAndSettle();

      expect(find.text('Digital Health Passport 🏥'), findsOneWidget);
      expect(find.text('Next ➔'), findsOneWidget);

      // Tap Next to advance to Card 3
      await tester.tap(find.text('Next ➔'));
      await tester.pumpAndSettle();

      expect(find.text('Real-time Chat & SOS 🚨'), findsOneWidget);
      expect(find.text('Get Started 🎉'), findsOneWidget);
    });
  });
}
