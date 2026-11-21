import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:carpool_coordinator/models/models.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/services/matrix_service.dart';
import 'package:carpool_coordinator/screens/active_route_screen.dart';

// ---------------------------------------------------------------------------
// Minimal MatrixService stub for widget tests
// ---------------------------------------------------------------------------
class _FakeMatrixService extends MatrixService {
  final String fakeUsername;
  final List<String> checkinLog = [];

  _FakeMatrixService({
    required DatabaseService dbService,
    this.fakeUsername = '@driver:matrix.org',
  }) : super(dbService: dbService);

  @override
  String get username => fakeUsername;

  @override
  bool get isLoggedIn => true;

  @override
  Future<void> sendAttendanceCheckin(
    String scheduleId,
    int eventTimestamp,
    String memberId,
    String action,
    String driverId,
  ) async {
    checkinLog.add('$memberId:$action');
  }

  @override
  Future<void> sendAlert(String scheduleId, String type, String message) async {}

  @override
  Future<void> sendLocation(
    String scheduleId,
    double lat,
    double lng,
    List<Map<String, dynamic>> riders,
  ) async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Future<DatabaseService> _buildDb({
  bool includeRiders = true,
  bool driverCoordsZero = false,
  bool riderPinRequired = false,
  String riderPin = '',
}) async {
  final db = DatabaseService();
  await db.initDatabase(inMemoryPath: inMemoryDatabasePath);

  final schedule = Schedule(
    scheduleId: 'sched_test',
    title: 'Test Soccer',
    icalFeedUrl: '',
    latitude: 34.0415,
    longitude: -118.4520,
    addressText: 'Clover Park Field 2',
  );
  await db.insertSchedule(schedule);

  final driverFamily = Family(
    matrixId: '@driver:matrix.org',
    familyName: 'Driver Family',
    latitude: driverCoordsZero ? 0.0 : 34.0522,
    longitude: driverCoordsZero ? 0.0 : -118.2437,
    addressText: '123 Driver St',
    lastUpdated: 0,
  );
  await db.insertFamily(driverFamily);

  final driverMember = FamilyMember(
    memberId: 'driver_mem',
    matrixId: '@driver:matrix.org',
    name: 'Test Driver',
    role: 'parent',
    isAdult: true,
    canDrive: true,
  );
  await db.insertFamilyMember(driverMember);

  await db.insertSignup(Signup(
    id: 'signup_driver',
    scheduleId: 'sched_test',
    eventTimestamp: 1700000000000,
    memberId: 'driver_mem',
    role: 'driver',
    status: 'scheduled',
  ));

  if (includeRiders) {
    final rider1Family = Family(
      matrixId: '@rider1:matrix.org',
      familyName: 'Rider1 Family',
      latitude: 34.0600,
      longitude: -118.2500,
      addressText: '456 Rider Ave',
      lastUpdated: 0,
    );
    await db.insertFamily(rider1Family);

    final rider1 = FamilyMember(
      memberId: 'rider1_mem',
      matrixId: '@rider1:matrix.org',
      name: 'Alice Rider',
      role: 'child',
      isAdult: false,
      requiresBoosterSeat: false,
      medicalNotes: '',
    );
    await db.insertFamilyMember(rider1);

    await db.insertSignup(Signup(
      id: 'signup_rider1',
      scheduleId: 'sched_test',
      eventTimestamp: 1700000000000,
      memberId: 'rider1_mem',
      role: 'rider',
      status: 'scheduled',
      handoffPinRequired: riderPinRequired,
      handoffPin: riderPin,
    ));
  }

  return db;
}

Widget _buildTestApp(DatabaseService db, _FakeMatrixService matrix) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DatabaseService>.value(value: db),
      ChangeNotifierProvider<MatrixService>.value(value: matrix),
    ],
    child: MaterialApp(
      home: ActiveRouteScreen(
        scheduleId: 'sched_test',
        eventTimestamp: 1700000000000,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests — Task 3: data resolution
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('ActiveRouteScreen — Task 3: data resolution', () {
    testWidgets('shows empty state when no riders found', (tester) async {
      final db = await _buildDb(includeRiders: false);
      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      // Let async loading complete
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.text('No riders for this carpool'), findsOneWidget);
    });

    testWidgets('shows missing coords banner when driver family unset', (tester) async {
      final db = await _buildDb(driverCoordsZero: true);
      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('home address is not set'), findsOneWidget);
    });

    testWidgets('renders waypoints for 1 rider signup (driver_start + pickup + destination)', (tester) async {
      final db = await _buildDb();

      // Add a 2nd rider for a 4-waypoint test
      final rider2Family = Family(
        matrixId: '@rider2:matrix.org',
        familyName: 'Rider2 Family',
        latitude: 34.0700,
        longitude: -118.2600,
        addressText: '789 Rider Blvd',
        lastUpdated: 0,
      );
      await db.insertFamily(rider2Family);
      final rider2 = FamilyMember(
        memberId: 'rider2_mem',
        matrixId: '@rider2:matrix.org',
        name: 'Bob Rider',
        role: 'child',
        isAdult: false,
      );
      await db.insertFamilyMember(rider2);
      await db.insertSignup(Signup(
        id: 'signup_rider2',
        scheduleId: 'sched_test',
        eventTimestamp: 1700000000000,
        memberId: 'rider2_mem',
        role: 'rider',
        status: 'scheduled',
      ));

      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2 riders → 4 waypoints: start + 2 pickups + destination
      // Expect pickup names present
      expect(find.textContaining('Alice Rider'), findsWidgets);
      expect(find.textContaining('Bob Rider'), findsWidgets);
      // Expect destination text
      expect(find.textContaining('Destination'), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Tests — Task 4: PIN handoff verification
  // ---------------------------------------------------------------------------

  group('ActiveRouteScreen — Task 4: PIN verification', () {
    testWidgets('wrong PIN shows error snackbar and does not record check-in', (tester) async {
      final db = await _buildDb(riderPinRequired: true, riderPin: '5678');
      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tap 'Child Boarded' button
      await tester.tap(find.text('Child Boarded').first);
      await tester.pumpAndSettle();

      // Enter wrong PIN
      await tester.enterText(find.byType(TextField).last, '0000');
      await tester.tap(find.text('Verify PIN'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Invalid PIN'), findsOneWidget);
      expect(matrix.checkinLog, isEmpty);
    });

    testWidgets('correct PIN records check-in and updates button', (tester) async {
      final db = await _buildDb(riderPinRequired: true, riderPin: '5678');
      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Child Boarded').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '5678');
      await tester.tap(find.text('Verify PIN'));
      await tester.pumpAndSettle();

      expect(matrix.checkinLog.isNotEmpty, isTrue);
      expect(find.text('Pickup Recorded'), findsOneWidget);
    });

    testWidgets('no PIN required records check-in without showing dialog', (tester) async {
      final db = await _buildDb(riderPinRequired: false);
      final matrix = _FakeMatrixService(dbService: db);
      await tester.pumpWidget(_buildTestApp(db, matrix));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      await tester.tap(find.text('Child Boarded').first);
      await tester.pumpAndSettle();

      // No PIN dialog should appear
      expect(find.text('Verify PIN'), findsNothing);
      expect(matrix.checkinLog.isNotEmpty, isTrue);
      expect(find.text('Pickup Recorded'), findsOneWidget);
    });
  });
}
