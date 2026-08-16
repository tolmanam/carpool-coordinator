import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/services/matrix_service.dart';
import 'package:carpool_coordinator/screens/circles_screen.dart';
import 'package:carpool_coordinator/screens/settings_screen.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('CirclesScreen renders title and create circle section', (WidgetTester tester) async {
    final dbService = DatabaseService();
    await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);
    final matrixService = MatrixService(dbService: dbService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DatabaseService>.value(value: dbService),
          ChangeNotifierProvider<MatrixService>.value(value: matrixService),
        ],
        child: const MaterialApp(home: Scaffold(body: CirclesScreen())),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Your Coordination Circles'), findsOneWidget);
    expect(find.text('Create New Circle'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders configuration sections', (WidgetTester tester) async {
    final dbService = DatabaseService();
    await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);
    final matrixService = MatrixService(dbService: dbService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<DatabaseService>.value(value: dbService),
          ChangeNotifierProvider<MatrixService>.value(value: matrixService),
        ],
        child: const MaterialApp(home: Scaffold(body: SettingsScreen())),
      ),
    );

    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('1. System Configuration'), findsOneWidget);
    expect(find.text('2. Profile Configuration'), findsOneWidget);
    expect(find.text('3. Family Group Configuration'), findsOneWidget);
  });
}
