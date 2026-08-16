import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import '../models/models.dart';

class MatrixService extends ChangeNotifier {
  final DatabaseService dbService;

  bool _isLoggedIn = false;
  String _username = '';
  String _homeserver = 'https://matrix.org';
  String _accessToken = '';
  bool _isOffline = false;

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get homeserver => _homeserver;
  String get accessToken => _accessToken;
  bool get isOffline => _isOffline;

  MatrixService({required this.dbService});

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('matrix_access_token') ?? '';
    _username = prefs.getString('matrix_username') ?? '';
    _homeserver = prefs.getString('matrix_homeserver') ?? 'https://matrix.org';
    _isLoggedIn = _accessToken.isNotEmpty && _username.isNotEmpty;
    notifyListeners();
  }

  Future<void> login(String username, String password, {String? homeserverUrl}) async {
    _username = username.trim();
    if (homeserverUrl != null && homeserverUrl.isNotEmpty) {
      _homeserver = homeserverUrl.trim();
    }
    _accessToken = 'syt_${_username}_mock_token_${DateTime.now().millisecondsSinceEpoch}';
    _isLoggedIn = true;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matrix_access_token', _accessToken);
    await prefs.setString('matrix_username', _username);
    await prefs.setString('matrix_homeserver', _homeserver);

    // Initialize default family record if missing
    final userMatrixId = _username.startsWith('@') ? _username : '@$_username:matrix.org';
    final existingFamily = await dbService.getFamily(userMatrixId);
    if (existingFamily == null) {
      await dbService.insertFamily(Family(
        matrixId: userMatrixId,
        familyName: 'The ${_username.replaceAll('@', '').split(':').first} Family',
        latitude: 34.0194,
        longitude: -118.4912,
        addressText: '734 Ocean Avenue, Santa Monica, CA',
        lastUpdated: DateTime.now().millisecondsSinceEpoch,
      ));

      await dbService.insertFamilyMember(FamilyMember(
        memberId: 'parent_${_username.replaceAll('@', '').split(':').first}',
        matrixId: userMatrixId,
        name: _username.replaceAll('@', '').split(':').first,
        role: 'parent',
      ));

      await dbService.insertFamilyMember(FamilyMember(
        memberId: 'child_${_username.replaceAll('@', '').split(':').first}',
        matrixId: userMatrixId,
        name: 'Alex',
        role: 'child',
      ));
    }

    notifyListeners();
  }

  Future<void> loginSSO({String? homeserverUrl}) async {
    final mockUser = '@sso_parent_${DateTime.now().millisecondsSinceEpoch % 1000}:matrix.org';
    await login(mockUser, 'sso_pass', homeserverUrl: homeserverUrl);
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _username = '';
    _accessToken = '';

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('matrix_access_token');
    await prefs.remove('matrix_username');

    notifyListeners();
  }

  void toggleOfflineMode(bool offline) {
    _isOffline = offline;
    notifyListeners();
  }

  // --- Circle & Room Operations ---
  Future<String> createCircle(String title) async {
    final scheduleId = 'sched_${DateTime.now().millisecondsSinceEpoch}';
    final schedule = Schedule(
      scheduleId: scheduleId,
      title: title,
      icalFeedUrl: '',
      latitude: 34.0415,
      longitude: -118.4520,
      addressText: 'Westside Community Center',
    );
    await dbService.insertSchedule(schedule);
    notifyListeners();
    return scheduleId;
  }

  Future<void> inviteMember(String scheduleId, String matrixIdOrEmail) async {
    notifyListeners();
  }
}
