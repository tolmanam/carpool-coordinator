import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:carpool_coordinator/config/app_info.dart';
import 'package:carpool_coordinator/widgets/about_app_dialog.dart';

void main() {
  group('AppInfo Tests', () {
    test('default values match expected fallback when dart-define is omitted', () {
      expect(AppInfo.appName, equals('Carpool Coordinator'));
      expect(AppInfo.appVersion, equals('1.0.0+1'));
      expect(AppInfo.gitTag, equals('Dev Build'));
      expect(AppInfo.gitCommit, equals('Dev Build'));
      expect(AppInfo.buildDate, equals('Dev Build'));
      expect(AppInfo.shortGitCommit, equals('Dev Build'));
    });
  });

  group('AboutAppDialog Widget Tests', () {
    testWidgets('displays AppInfo contents in dialog when triggered', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAboutAppDialog(context),
                child: const Text('Show About'),
              ),
            ),
          ),
        ),
      );

      // Tap button to open dialog
      await tester.tap(find.text('Show About'));
      await tester.pumpAndSettle();

      // Verify dialog title and contents
      expect(find.text('About Carpool Coordinator'), findsOneWidget);
      expect(find.text('App Name'), findsOneWidget);
      expect(find.text('Version'), findsOneWidget);
      expect(find.text('Release / Tag'), findsOneWidget);
      expect(find.text('Git Commit'), findsOneWidget);
      expect(find.text('Build Date'), findsOneWidget);
      expect(find.text('Dev Build'), findsAtLeastNWidgets(1));

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('About Carpool Coordinator'), findsNothing);
    });
  });
}
