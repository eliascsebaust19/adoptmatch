import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adoptmatch/shared/widgets/logout_confirmation_dialog.dart';

void main() {
  testWidgets('AdoptMatchLogoutDialog renders design specification elements correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showAdoptMatchLogoutDialog(context),
              child: const Text('Open Dialog'),
            ),
          ),
        ),
      ),
    );

    // Tap to open dialog
    await tester.tap(find.text('Open Dialog'));
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Log Out of AdoptMatch?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to log out? You will need to sign in again to swipe, chat with shelters, and access health passports.'),
      findsOneWidget,
    );

    // Verify Icon
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

    // Verify Buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Yes, Log Out'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify Dialog dismissed
    expect(find.text('Log Out of AdoptMatch?'), findsNothing);
  });
}
