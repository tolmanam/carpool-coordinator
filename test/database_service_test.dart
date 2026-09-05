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
        isAdult: false,
        canDrive: false,
        email: 'john@example.com',
        phone: '555-0199',
        emergencyContact: 'Sarah Connor',
      );

      await dbService.insertFamilyMember(member);
      final members = await dbService.getFamilyMembers('@alice:matrix.org');

      expect(members.length, equals(1));
      expect(members.first.name, equals('John Connor'));
      expect(members.first.isAdult, isFalse);
      expect(members.first.email, equals('john@example.com'));
    });

    test('Organization, Carpool Circles, Participants and Chat Messages CRUD', () async {
      final org = Organization(
        orgId: 'org_1',
        name: 'Westside Gymnastics',
        icalFeedUrl: 'https://example.com/gymnastics.ics',
      );
      await dbService.insertOrganization(org);

      final fetchedOrg = await dbService.getOrganization('org_1');
      expect(fetchedOrg, isNotNull);
      expect(fetchedOrg!.name, equals('Westside Gymnastics'));

      final circle = CarpoolCircle(
        circleId: 'circle_1',
        orgId: 'org_1',
        name: 'Tuesday Carpool Circle',
      );
      await dbService.insertCarpoolCircle(circle);

      final circles = await dbService.getCarpoolCircles('org_1');
      expect(circles.length, equals(1));
      expect(circles.first.name, equals('Tuesday Carpool Circle'));

      final participant = OrganizationParticipant(
        id: 'p_1',
        orgId: 'org_1',
        memberId: 'mem_1',
        circleId: 'circle_1',
      );
      await dbService.insertOrgParticipant(participant);

      final participants = await dbService.getOrgParticipants('org_1');
      expect(participants.length, equals(1));
      expect(participants.first.memberId, equals('mem_1'));

      final chatMsg = ChatMessage(
        id: 'msg_1',
        roomId: 'circle_1',
        senderId: '@alice:matrix.org',
        senderName: 'Alice',
        content: 'Hi everyone!',
        timestamp: 1698391800000,
      );
      await dbService.insertChatMessage(chatMsg);

      final msgs = await dbService.getChatMessages('circle_1');
      expect(msgs.length, equals(1));
      expect(msgs.first.content, equals('Hi everyone!'));
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
