import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/models/models.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseService Tests', () {
    late DatabaseService dbService;

    setUp(() async {
      dbService = DatabaseService();
      await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);
    });

    test('Insert and retrieve family and family members', () async {
      final family = Family(
        matrixId: '@alice:matrix.org',
        familyName: 'The Connor Family',
        latitude: 34.0194,
        longitude: -118.4912,
        addressText: '734 Ocean Avenue',
        lastUpdated: 1698391800000,
      );

      await dbService.insertFamily(family);
      final fetchedFamily = await dbService.getFamily('@alice:matrix.org');

      expect(fetchedFamily, isNotNull);
      expect(fetchedFamily!.familyName, equals('The Connor Family'));

      final member = FamilyMember(
        memberId: 'mem_1',
        matrixId: '@alice:matrix.org',
        name: 'John Connor',
        role: 'child',
      );

      await dbService.insertFamilyMember(member);
      final members = await dbService.getFamilyMembers('@alice:matrix.org');

      expect(members.length, equals(1));
      expect(members.first.name, equals('John Connor'));
    });

    test('Insert and retrieve schedule and signups', () async {
      final schedule = Schedule(
        scheduleId: 'sched_soccer',
        title: 'Westside Soccer',
        icalFeedUrl: 'https://example.com/feed.ics',
        latitude: 34.0415,
        longitude: -118.4520,
        addressText: 'Clover Park Field 2',
      );

      await dbService.insertSchedule(schedule);
      final schedules = await dbService.getSchedules();

      expect(schedules.length, equals(1));
      expect(schedules.first.title, equals('Westside Soccer'));

      final signup = Signup(
        id: 'signup_1',
        scheduleId: 'sched_soccer',
        eventTimestamp: 1698393600000,
        memberId: 'mem_1',
        role: 'rider',
        status: 'scheduled',
      );

      await dbService.insertSignup(signup);
      final signups = await dbService.getSignups('sched_soccer');

      expect(signups.length, equals(1));
      expect(signups.first.role, equals('rider'));
    });
  });
}
