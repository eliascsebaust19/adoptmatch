import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adoptmatch/core/services/local_storage_service.dart';
import 'package:adoptmatch/core/repositories/application_repository.dart';
import 'package:adoptmatch/features/auth/bloc/auth_bloc.dart';
import 'package:adoptmatch/features/admin/screens/admin_dashboard_screen.dart';
import 'package:adoptmatch/features/application/screens/adoption_application_screen.dart';
import 'package:adoptmatch/shared/widgets/paw_logo.dart';
import 'package:adoptmatch/shared/widgets/status_badge.dart';
import 'package:adoptmatch/shared/widgets/custom_button.dart';

void main() {
  testWidgets('PawLogo widget renders successfully', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: PawLogo(size: 64)),
        ),
      ),
    );

    expect(find.byType(PawLogo), findsOneWidget);
  });

  testWidgets('MatchScoreBadge displays correct percentage', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: MatchScoreBadge(score: 95),
          ),
        ),
      ),
    );

    expect(find.text('95% Match'), findsOneWidget);
    expect(find.byIcon(Icons.bolt), findsOneWidget);
  });

  testWidgets('CustomButton handles tap and displays text', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: CustomButton(
              text: 'Apply for Adoption',
              onPressed: () {
                tapped = true;
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text('Apply for Adoption'), findsOneWidget);
    await tester.tap(find.text('Apply for Adoption'));
    expect(tapped, isTrue);
  });

  testWidgets('AdminDashboardScreen renders without error with KPI cards and tabs', (WidgetTester tester) async {
    final authBloc = AuthBloc(
      initialUser: const UserProfile(
        id: 'admin-test-01',
        name: 'Admin Test',
        email: 'admin@adoptmatch.com',
        phone: '+880 1800 000000',
        role: UserRole.admin,
      ),
    );

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      BlocProvider<AuthBloc>.value(
        value: authBloc,
        child: const MaterialApp(
          home: AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AdminDashboardScreen), findsOneWidget);
    expect(find.text('Shelter Management Admin'), findsOneWidget);
  });

  testWidgets('AdoptionApplicationScreen renders and advances to step 2', (WidgetTester tester) async {
    LocalStorageService.instance.resetForTesting();
    ApplicationRepository().resetForTesting();
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(
        home: AdoptionApplicationScreen(petId: 'p1'),
      ),
    );
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final textFields = find.byType(TextField);
    if (textFields.evaluate().length >= 7) {
      await tester.enterText(textFields.at(0), 'Test Applicant');
      await tester.enterText(textFields.at(1), '+880 1711 000000');
      await tester.enterText(textFields.at(2), 'test@example.com');
      await tester.enterText(textFields.at(3), '1995-1234-5678-0000');
      await tester.enterText(textFields.at(4), 'Emergency Contact');
      await tester.enterText(textFields.at(5), '+880 1811 000000');
      await tester.enterText(textFields.at(6), 'House 1, Road 1, Dhaka');
      await tester.pump();
    }

    final nextBtn = find.text('Continue to Step 2');
    await tester.ensureVisible(nextBtn);
    await tester.pump();
    await tester.tap(nextBtn);
    for (int i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('2. Housing & Environment'), findsOneWidget);
    expect(find.text('Continue to Step 3'), findsOneWidget);
  });
}
