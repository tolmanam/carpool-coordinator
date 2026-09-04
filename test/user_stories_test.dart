import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/services/matrix_service.dart';
import 'package:carpool_coordinator/models/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('User Stories Unit Tests (US-101 through US-404)', () {
    late DatabaseService dbService;
    late MatrixService matrixService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbService = DatabaseService();
      await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);
      matrixService = MatrixService(dbService: dbService);
    });

    test('US-101 & US-102: Family Profile & Family Member Management', () async {
      final family = Family(
        matrixId: '@parent:matrix.org',
        familyName: 'The Smith Family',
        latitude: 34.0522,
        longitude: -118.2437,
        addressText: '100 Main St, Los Angeles, CA',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      );

      await dbService.insertFamily(family);
      final retrievedFamily = await dbService.getFamily('@parent:matrix.org');

      expect(retrievedFamily, isNotNull);
      expect(retrievedFamily!.familyName, equals('The Smith Family'));
      expect(retrievedFamily.latitude, equals(34.0522));

      final child = FamilyMember(
        memberId: 'child_1',
        matrixId: '@parent:matrix.org',
        name: 'Tommy Smith',
        role: 'child',
      );

      await dbService.insertFamilyMember(child);
      final members = await dbService.getFamilyMembers('@parent:matrix.org');

      expect(members.length, equals(1));
      expect(members.first.name, equals('Tommy Smith'));
      expect(members.first.role, equals('child'));
    });

    test('US-103 & US-302: Circle Creation and Matrix Room Invitation', () async {
      final scheduleId = await matrixService.createCircle('Soccer Team Circle');
      final schedules = await dbService.getSchedules();

      expect(schedules.length, equals(1));
      expect(schedules.first.title, equals('Soccer Team Circle'));
      expect(scheduleId, isNotEmpty);

      await matrixService.inviteMember(scheduleId, '@other_parent:matrix.org');
    });

    test('US-104 & US-105: Ride Registration and Participant Opt-Out', () async {
      final scheduleId = 'sched_soccer';
      final eventTimestamp = 1700000000000;
      final childId = 'child_1';

      // US-104: Register ride
      final signup = Signup(
        id: 'signup_1',
        scheduleId: scheduleId,
        eventTimestamp: eventTimestamp,
        memberId: childId,
        role: 'rider',
        status: 'scheduled',
      );

      await dbService.insertSignup(signup);
      var signups = await dbService.getSignups(scheduleId);
      expect(signups.length, equals(1));
      expect(signups.first.role, equals('rider'));

      // US-105: Cancel registration / Opt-out
      await dbService.deleteSignup(scheduleId, eventTimestamp, childId);
      signups = await dbService.getSignups(scheduleId);
      expect(signups.isEmpty, isTrue);
    });

    test('US-201 & US-205: Drive Sign-Up and Driver Replacement', () async {
      final scheduleId = 'sched_soccer';
      final eventTimestamp = 1700000000000;
      final driver1 = 'driver_alice';
      final driver2 = 'driver_bob';

      // US-201: Alice signs up as driver
      final signup1 = Signup(
        id: 'signup_alice',
        scheduleId: scheduleId,
        eventTimestamp: eventTimestamp,
        memberId: driver1,
        role: 'driver',
        status: 'scheduled',
      );
      await dbService.insertSignup(signup1);

      var signups = await dbService.getSignups(scheduleId);
      expect(signups.where((s) => s.role == 'driver').first.memberId, equals(driver1));

      // US-205: Driver replacement (Alice cancels, Bob takes over)
      await dbService.deleteSignup(scheduleId, eventTimestamp, driver1);

      final signup2 = Signup(
        id: 'signup_bob',
        scheduleId: scheduleId,
        eventTimestamp: eventTimestamp,
        memberId: driver2,
        role: 'driver',
        status: 'scheduled',
      );
      await dbService.insertSignup(signup2);

      signups = await dbService.getSignups(scheduleId);
      expect(signups.where((s) => s.role == 'driver').first.memberId, equals(driver2));
    });

    test('US-401 & US-403: Matrix Authentication & Offline First Sync', () async {
      expect(matrixService.isLoggedIn, isFalse);

      matrixService.toggleOfflineMode(true);
      await matrixService.login('@testuser:matrix.org', 'password123', homeserverUrl: 'https://matrix.org');

      expect(matrixService.isLoggedIn, isTrue);
      expect(matrixService.username, equals('@testuser:matrix.org'));
      expect(matrixService.isOffline, isTrue);

      // Verify offline data settings retrieval works from local SQLite
      await dbService.setSetting('theme_mode', 'dark');
      final val = await dbService.getSetting('theme_mode');
      expect(val, equals('dark'));
    });
  });
}
