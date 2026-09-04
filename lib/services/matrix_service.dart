import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'database_service.dart';
import '../models/models.dart';

class MatrixService extends ChangeNotifier {
  final DatabaseService dbService;
  final http.Client _client;

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

  MatrixService({required this.dbService, http.Client? client})
      : _client = client ?? http.Client();

  String _cleanUrl(String url) {
    var cleaned = url.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'https://$cleaned';
    }
    if (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    return cleaned;
  }

  Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString('matrix_access_token') ?? '';
    _username = prefs.getString('matrix_username') ?? '';
    _homeserver = prefs.getString('matrix_homeserver') ?? 'https://matrix.org';
    _isLoggedIn = _accessToken.isNotEmpty && _username.isNotEmpty;

    if (_isLoggedIn && !_isOffline) {
      // Sync joined rooms on session load
      unawaited(syncJoinedRooms());
    }
    notifyListeners();
  }

  Future<void> login(String username, String password, {String? homeserverUrl}) async {
    if (homeserverUrl != null && homeserverUrl.isNotEmpty) {
      _homeserver = _cleanUrl(homeserverUrl);
    }

    final rawUser = username.trim();
    final userIdentifier = rawUser.startsWith('@')
        ? rawUser.split(':').first.substring(1)
        : rawUser;

    if (_isOffline) {
      // Offline fallback login for caching/testing
      _username = rawUser.startsWith('@') ? rawUser : '@$rawUser:${Uri.parse(_homeserver).host}';
      _accessToken = 'syt_${_username}_offline_token_${DateTime.now().millisecondsSinceEpoch}';
      _isLoggedIn = true;
    } else {
      final loginUri = Uri.parse('$_homeserver/_matrix/client/v3/login');
      final response = await _client.post(
        loginUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': 'm.login.password',
          'identifier': {
            'type': 'm.id.user',
            'user': userIdentifier,
          },
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _username = data['user_id'] as String;
        _isLoggedIn = true;
      } else {
        final errJson = jsonDecode(response.body);
        final errMsg = errJson['error'] ?? 'Matrix login failed (${response.statusCode})';
        throw Exception(errMsg);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matrix_access_token', _accessToken);
    await prefs.setString('matrix_username', _username);
    await prefs.setString('matrix_homeserver', _homeserver);

    // Sync rooms on successful login
    await syncJoinedRooms();

    notifyListeners();
  }

  String getSsoRedirectUrl({String? homeserverUrl}) {
    final hs = homeserverUrl != null && homeserverUrl.isNotEmpty
        ? _cleanUrl(homeserverUrl)
        : _homeserver;
    return '$hs/_matrix/client/v3/login/sso/redirect?redirectUrl=https://matrix.org';
  }

  Future<void> syncJoinedRooms() async {
    if (_isOffline || !_isLoggedIn) return;

    try {
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/joined_rooms');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> joinedRooms = data['joined_rooms'] ?? [];

        for (final roomId in joinedRooms) {
          final roomStr = roomId as String;
          // Query room name / details
          final nameUri = Uri.parse('$_homeserver/_matrix/client/v3/rooms/$roomStr/state/m.room.name');
          final nameResp = await _client.get(
            nameUri,
            headers: {'Authorization': 'Bearer $_accessToken'},
          );

          String title = 'Matrix Circle ($roomStr)';
          if (nameResp.statusCode == 200) {
            final nameData = jsonDecode(nameResp.body);
            if (nameData['name'] != null && (nameData['name'] as String).isNotEmpty) {
              title = nameData['name'];
            }
          }

          final schedule = Schedule(
            scheduleId: roomStr,
            title: title,
            icalFeedUrl: '',
            latitude: 34.0415,
            longitude: -118.4520,
            addressText: 'Matrix Room Circle',
            homeserverUrl: _homeserver,
          );
          await dbService.insertSchedule(schedule);
        }
      }
    } catch (e) {
      debugPrint('Error syncing joined Matrix rooms: $e');
    }
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
  Future<String> createCircle(String title, {String? icalFeedUrl}) async {
    String scheduleId = 'room_${DateTime.now().millisecondsSinceEpoch}';

    if (!_isOffline && _isLoggedIn) {
      final createUri = Uri.parse('$_homeserver/_matrix/client/v3/createRoom');
      final response = await _client.post(
        createUri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'name': title,
          'preset': 'private_chat',
          'visibility': 'private',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        scheduleId = data['room_id'] as String;
      } else {
        final errJson = jsonDecode(response.body);
        throw Exception(errJson['error'] ?? 'Failed to create Matrix room (${response.statusCode})');
      }
    }

    final schedule = Schedule(
      scheduleId: scheduleId,
      title: title,
      icalFeedUrl: icalFeedUrl ?? '',
      latitude: 34.0415,
      longitude: -118.4520,
      addressText: 'Matrix Room Circle',
      homeserverUrl: _homeserver,
    );
    await dbService.insertSchedule(schedule);
    notifyListeners();
    return scheduleId;
  }

  String generateEmailInviteLink(String scheduleId, String circleTitle, String recipientEmail) {
    final cleanRoomId = Uri.encodeComponent(scheduleId);
    final joinLink = 'https://matrix.to/#/$cleanRoomId';
    final subject = Uri.encodeComponent('Join $circleTitle on Carpool Coordinator');
    final body = Uri.encodeComponent(
      'You have been invited to join the Carpool Coordinator circle "$circleTitle".\n\n'
      'Click the link below to join the encrypted Matrix room:\n$joinLink\n\n'
      'Homeserver: $_homeserver',
    );
    return 'mailto:$recipientEmail?subject=$subject&body=$body';
  }

  Future<void> inviteMember(String scheduleId, String matrixId) async {
    if (_isOffline || !_isLoggedIn) {
      notifyListeners();
      return;
    }

    final inviteUri = Uri.parse('$_homeserver/_matrix/client/v3/rooms/$scheduleId/invite');
    final response = await _client.post(
      inviteUri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_accessToken',
      },
      body: jsonEncode({'user_id': matrixId}),
    );

    if (response.statusCode != 200) {
      final errJson = jsonDecode(response.body);
      throw Exception(errJson['error'] ?? 'Failed to invite user to room (${response.statusCode})');
    }
    notifyListeners();
  }
}
