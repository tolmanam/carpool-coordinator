import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carpool_coordinator/widgets/empty_state_widget.dart';
import 'package:carpool_coordinator/screens/onboarding_screen.dart';

void main() {
  testWidgets('EmptyStateWidget renders title, icon, and button', (WidgetTester tester) async {
    bool pressed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyStateWidget(
            icon: Icons.calendar_today,
            title: 'No Events Scheduled',
            description: 'Import an iCal calendar feed to see your commutes.',
            buttonText: 'Add Calendar Feed',
            onButtonPressed: () => pressed = true,
          ),
        ),
      ),
    );

    expect(find.text('No Events Scheduled'), findsOneWidget);
    expect(find.text('Import an iCal calendar feed to see your commutes.'), findsOneWidget);
    expect(find.text('Add Calendar Feed'), findsOneWidget);

    await tester.tap(find.text('Add Calendar Feed'));
    expect(pressed, isTrue);
  });

  testWidgets('OnboardingScreen navigates pages and completes', (WidgetTester tester) async {
    bool completed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(onCompleted: () => completed = true),
      ),
    );

    expect(find.text('Welcome to Carpool Coordinator'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    expect(completed, isTrue);
  });
}
