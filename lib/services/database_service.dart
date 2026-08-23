import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
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

    final String path = inMemoryPath ?? p.join(await getDatabasesPath(), 'carpool_coordinator.db');

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
            FOREIGN KEY (matrix_id) REFERENCES cached_families (matrix_id) ON DELETE CASCADE
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
}
