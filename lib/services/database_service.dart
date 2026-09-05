import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

import '../models/models.dart';

class DatabaseService extends ChangeNotifier {
  Database? _db;

  Database get db {
    if (_db == null) {
      throw Exception('Database not initialized. Call initDatabase() first.');
    }
    return _db!;
  }

  Future<void> initDatabase({String? inMemoryPath}) async {
    if (_db != null) return;

    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    }

    final String path = inMemoryPath ?? (kIsWeb ? 'carpool_coordinator.db' : p.join(await getDatabasesPath(), 'carpool_coordinator.db'));

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_families (
            matrix_id TEXT PRIMARY KEY,
            family_name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address_text TEXT,
            last_updated INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_family_members (
            member_id TEXT PRIMARY KEY,
            matrix_id TEXT NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            is_adult INTEGER DEFAULT 1,
            can_drive INTEGER DEFAULT 0,
            member_matrix_id TEXT,
            email TEXT,
            avatar_url TEXT,
            phone TEXT,
            emergency_contact TEXT,
            FOREIGN KEY (matrix_id) REFERENCES cached_families (matrix_id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_organizations (
            org_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            ical_feed_url TEXT,
            matrix_space_id TEXT,
            homeserver_url TEXT DEFAULT 'https://matrix.org'
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_carpool_circles (
            circle_id TEXT PRIMARY KEY,
            org_id TEXT NOT NULL,
            name TEXT NOT NULL,
            matrix_room_id TEXT,
            pickup_address TEXT,
            FOREIGN KEY (org_id) REFERENCES cached_organizations (org_id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_org_participants (
            id TEXT PRIMARY KEY,
            org_id TEXT NOT NULL,
            member_id TEXT NOT NULL,
            circle_id TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_chat_messages (
            id TEXT PRIMARY KEY,
            room_id TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            sender_name TEXT NOT NULL,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_schedules (
            schedule_id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            ical_feed_url TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address_text TEXT,
            homeserver_url TEXT DEFAULT 'https://matrix.org'
          )
        ''');

        await db.execute('''
          CREATE TABLE local_ical_events (
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            title TEXT NOT NULL,
            start_time INTEGER NOT NULL,
            end_time INTEGER NOT NULL,
            FOREIGN KEY (schedule_id) REFERENCES cached_schedules (schedule_id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_signups (
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            event_timestamp INTEGER NOT NULL,
            member_id TEXT NOT NULL,
            role TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE cached_routes (
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            event_timestamp INTEGER NOT NULL,
            driver_id TEXT NOT NULL,
            estimated_departure INTEGER NOT NULL,
            waypoints_json TEXT NOT NULL,
            route_polyline TEXT
          )
        ''');
      },
    );
    notifyListeners();
  }

  // --- Settings CRUD ---
  Future<void> setSetting(String key, String value) async {
    await db.insert(
      'local_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<String?> getSetting(String key) async {
    final res = await db.query(
      'local_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (res.isNotEmpty) {
      return res.first['value'] as String?;
    }
    return null;
  }

  // --- Schedules CRUD ---
  Future<List<Schedule>> getSchedules() async {
    final res = await db.query('cached_schedules');
    return res.map((m) => Schedule.fromMap(m)).toList();
  }

  Future<void> insertSchedule(Schedule schedule) async {
    await db.insert(
      'cached_schedules',
      schedule.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  // --- Local iCal Events CRUD ---
  Future<List<LocalIcalEvent>> getIcalEvents(String scheduleId) async {
    final res = await db.query(
      'local_ical_events',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
      orderBy: 'start_time ASC',
    );
    return res.map((m) => LocalIcalEvent.fromMap(m)).toList();
  }

  Future<void> insertIcalEvents(List<LocalIcalEvent> events) async {
    final batch = db.batch();
    for (final e in events) {
      batch.insert('local_ical_events', e.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
    notifyListeners();
  }

  // --- Signups CRUD ---
  Future<List<Signup>> getSignups(String scheduleId) async {
    final res = await db.query(
      'cached_signups',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
    return res.map((m) => Signup.fromMap(m)).toList();
  }

  Future<void> insertSignup(Signup signup) async {
    await db.insert(
      'cached_signups',
      signup.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> deleteSignup(String scheduleId, int eventTimestamp, String memberId) async {
    await db.delete(
      'cached_signups',
      where: 'schedule_id = ? AND event_timestamp = ? AND member_id = ?',
      whereArgs: [scheduleId, eventTimestamp, memberId],
    );
    notifyListeners();
  }

  // --- Families & Members CRUD ---
  Future<Family?> getFamily(String matrixId) async {
    final res = await db.query(
      'cached_families',
      where: 'matrix_id = ?',
      whereArgs: [matrixId],
    );
    if (res.isNotEmpty) {
      return Family.fromMap(res.first);
    }
    return null;
  }

  Future<void> insertFamily(Family family) async {
    await db.insert(
      'cached_families',
      family.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<List<FamilyMember>> getFamilyMembers(String matrixId) async {
    final res = await db.query(
      'cached_family_members',
      where: 'matrix_id = ?',
      whereArgs: [matrixId],
    );
    return res.map((m) => FamilyMember.fromMap(m)).toList();
  }

  Future<List<FamilyMember>> getAllFamilyMembers() async {
    final res = await db.query('cached_family_members');
    return res.map((m) => FamilyMember.fromMap(m)).toList();
  }

  Future<void> insertFamilyMember(FamilyMember member) async {
    await db.insert(
      'cached_family_members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> deleteFamilyMember(String memberId) async {
    await db.delete(
      'cached_family_members',
      where: 'member_id = ?',
      whereArgs: [memberId],
    );
    notifyListeners();
  }

  // --- Organizations CRUD ---
  Future<List<Organization>> getOrganizations() async {
    final res = await db.query('cached_organizations');
    return res.map((m) => Organization.fromMap(m)).toList();
  }

  Future<Organization?> getOrganization(String orgId) async {
    final res = await db.query(
      'cached_organizations',
      where: 'org_id = ?',
      whereArgs: [orgId],
    );
    if (res.isNotEmpty) return Organization.fromMap(res.first);
    return null;
  }

  Future<void> insertOrganization(Organization org) async {
    await db.insert(
      'cached_organizations',
      org.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> deleteOrganization(String orgId) async {
    await db.delete('cached_organizations', where: 'org_id = ?', whereArgs: [orgId]);
    notifyListeners();
  }

  // --- Carpool Circles CRUD ---
  Future<List<CarpoolCircle>> getCarpoolCircles(String orgId) async {
    final res = await db.query(
      'cached_carpool_circles',
      where: 'org_id = ?',
      whereArgs: [orgId],
    );
    return res.map((m) => CarpoolCircle.fromMap(m)).toList();
  }

  Future<List<CarpoolCircle>> getAllCarpoolCircles() async {
    final res = await db.query('cached_carpool_circles');
    return res.map((m) => CarpoolCircle.fromMap(m)).toList();
  }

  Future<void> insertCarpoolCircle(CarpoolCircle circle) async {
    await db.insert(
      'cached_carpool_circles',
      circle.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> deleteCarpoolCircle(String circleId) async {
    await db.delete('cached_carpool_circles', where: 'circle_id = ?', whereArgs: [circleId]);
    notifyListeners();
  }

  // --- Organization Participants CRUD ---
  Future<List<OrganizationParticipant>> getOrgParticipants(String orgId) async {
    final res = await db.query(
      'cached_org_participants',
      where: 'org_id = ?',
      whereArgs: [orgId],
    );
    return res.map((m) => OrganizationParticipant.fromMap(m)).toList();
  }

  Future<void> insertOrgParticipant(OrganizationParticipant participant) async {
    await db.insert(
      'cached_org_participants',
      participant.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }

  Future<void> deleteOrgParticipant(String orgId, String memberId) async {
    await db.delete(
      'cached_org_participants',
      where: 'org_id = ? AND member_id = ?',
      whereArgs: [orgId, memberId],
    );
    notifyListeners();
  }

  // --- Chat Messages CRUD ---
  Future<List<ChatMessage>> getChatMessages(String roomId) async {
    final res = await db.query(
      'cached_chat_messages',
      where: 'room_id = ?',
      whereArgs: [roomId],
      orderBy: 'timestamp ASC',
    );
    return res.map((m) => ChatMessage.fromMap(m)).toList();
  }

  Future<void> insertChatMessage(ChatMessage msg) async {
    await db.insert(
      'cached_chat_messages',
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    notifyListeners();
  }
}
