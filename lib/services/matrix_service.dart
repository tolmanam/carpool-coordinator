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
  String _deviceId = '';
  String _syncToken = '';
  bool _isOffline = false;

  List<MatrixDevice> _devices = [];

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get homeserver => _homeserver;
  String get accessToken => _accessToken;
  String get deviceId => _deviceId;
  String get syncToken => _syncToken;
  bool get isOffline => _isOffline;
  List<MatrixDevice> get devices => List.unmodifiable(_devices);

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
    _deviceId = prefs.getString('matrix_device_id') ?? '';
    _syncToken = prefs.getString('matrix_sync_token') ?? '';
    _isLoggedIn = _accessToken.isNotEmpty && _username.isNotEmpty;

    if (_isLoggedIn && !_isOffline) {
      unawaited(fetchDevices());
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
      _username = rawUser.startsWith('@') ? rawUser : '@$rawUser:${Uri.parse(_homeserver).host}';
      _accessToken = 'syt_${_username}_offline_token_${DateTime.now().millisecondsSinceEpoch}';
      _deviceId = 'OFFLINE_DEVICE_1';
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
          'initial_device_display_name': 'Carpool Coordinator App',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'] as String;
        _username = data['user_id'] as String;
        _deviceId = data['device_id'] as String? ?? 'DEVICE_${DateTime.now().millisecondsSinceEpoch}';
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
    await prefs.setString('matrix_device_id', _deviceId);

    await uploadKeys();
    await fetchDevices();
    await syncJoinedRooms();

    notifyListeners();
  }

  String getSsoRedirectUrl({String? homeserverUrl}) {
    final hs = homeserverUrl != null && homeserverUrl.isNotEmpty
        ? _cleanUrl(homeserverUrl)
        : _homeserver;
    return '$hs/_matrix/client/v3/login/sso/redirect?redirectUrl=https://matrix.org';
  }

  // --- Device Management & Verification ---

  Future<void> fetchDevices() async {
    if (_isOffline || !_isLoggedIn) {
      _devices = [
        MatrixDevice(
          deviceId: _deviceId.isNotEmpty ? _deviceId : 'OFFLINE_DEVICE_1',
          displayName: 'Current Device (Offline Mock)',
          verificationStatus: 'Verified',
        ),
      ];
      notifyListeners();
      return;
    }

    try {
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/devices');
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> deviceList = data['devices'] ?? [];
        final prefs = await SharedPreferences.getInstance();

        _devices = deviceList.map((d) {
          final devMap = d as Map<String, dynamic>;
          final devId = devMap['device_id'] as String;
          final savedStatus = prefs.getString('matrix_device_status_$devId') ??
              (devId == _deviceId ? 'Verified' : 'Unverified');

          return MatrixDevice.fromMap({
            ...devMap,
            'verification_status': savedStatus,
          });
        }).toList();
      }
    } catch (e) {
      debugPrint('Error fetching Matrix devices: $e');
    }
    notifyListeners();
  }

  Future<void> verifyDevice(String targetDeviceId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('matrix_device_status_$targetDeviceId', status);

    _devices = _devices.map((d) {
      if (d.deviceId == targetDeviceId) {
        return d.copyWith(verificationStatus: status);
      }
      return d;
    }).toList();

    notifyListeners();
  }

  Future<void> uploadKeys() async {
    if (_isOffline || !_isLoggedIn) return;

    try {
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/keys/upload');
      await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'device_keys': {
            'user_id': _username,
            'device_id': _deviceId,
            'algorithms': [
              'm.olsen.v1.curve25519-aes-sha2',
              'm.megolm.v1.aes-sha2',
            ],
            'keys': {
              'curve25519:$_deviceId': 'mock_curve25519_key_$_deviceId',
              'ed25519:$_deviceId': 'mock_ed25519_key_$_deviceId',
            },
          },
        }),
      );
    } catch (e) {
      debugPrint('Error uploading device keys: $e');
    }
  }

  Future<Map<String, dynamic>> queryKeys(List<String> userIds) async {
    if (_isOffline || !_isLoggedIn) return {};

    try {
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/keys/query');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'device_keys': {
            for (var uid in userIds) uid: [],
          },
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error querying user device keys: $e');
    }
    return {};
  }

  // --- Matrix Sync Loop & Event Handling ---

  Future<void> syncJoinedRooms() async {
    if (_isOffline || !_isLoggedIn) return;

    try {
      var syncUrl = '$_homeserver/_matrix/client/v3/sync?timeout=10000';
      if (_syncToken.isNotEmpty) {
        syncUrl += '&since=$_syncToken';
      }

      final response = await _client.get(
        Uri.parse(syncUrl),
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        _syncToken = data['next_batch'] as String? ?? _syncToken;

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('matrix_sync_token', _syncToken);

        final rooms = data['rooms']?['join'] as Map<String, dynamic>? ?? {};

        for (final roomId in rooms.keys) {
          final roomData = rooms[roomId] as Map<String, dynamic>;
          final stateEvents = roomData['state']?['events'] as List<dynamic>? ?? [];
          final timelineEvents = roomData['timeline']?['events'] as List<dynamic>? ?? [];

          String title = 'Matrix Circle ($roomId)';

          for (final event in [...stateEvents, ...timelineEvents]) {
            final evMap = event as Map<String, dynamic>;
            final type = evMap['type'] as String?;

            if (type == 'm.room.name') {
              final name = evMap['content']?['name'] as String?;
              if (name != null && name.isNotEmpty) {
                title = name;
              }
            } else if (type == 'org.carpool.signup') {
              final content = evMap['content'] as Map<String, dynamic>? ?? {};
              if (content.containsKey('member_id')) {
                final signup = Signup(
                  id: evMap['event_id'] as String? ?? 'signup_${DateTime.now().millisecondsSinceEpoch}',
                  scheduleId: roomId,
                  eventTimestamp: content['event_timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
                  memberId: content['member_id'] as String,
                  role: content['role'] as String? ?? 'rider',
                  status: content['status'] as String? ?? 'scheduled',
                );
                await dbService.insertSignup(signup);
              }
            }
          }

          final schedule = Schedule(
            scheduleId: roomId,
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
      debugPrint('Error syncing Matrix events: $e');
    }
  }

  // --- Event Dispatching ---

  Future<void> sendSignup(String scheduleId, String memberId, String role, String status, int eventTimestamp) async {
    final signup = Signup(
      id: 'signup_${DateTime.now().millisecondsSinceEpoch}',
      scheduleId: scheduleId,
      eventTimestamp: eventTimestamp,
      memberId: memberId,
      role: role,
      status: status,
    );
    await dbService.insertSignup(signup);

    if (!_isOffline && _isLoggedIn) {
      final txnId = 'm${DateTime.now().millisecondsSinceEpoch}';
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/rooms/$scheduleId/send/org.carpool.signup/$txnId');

      await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'member_id': memberId,
          'role': role,
          'status': status,
          'event_timestamp': eventTimestamp,
        }),
      );
    }
    notifyListeners();
  }

  Future<void> sendLocation(String scheduleId, double lat, double lng, List<Map<String, dynamic>> etaUpdates) async {
    if (!_isOffline && _isLoggedIn) {
      final txnId = 'm${DateTime.now().millisecondsSinceEpoch}';
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/rooms/$scheduleId/send/org.carpool.location/$txnId');

      await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'schedule_id': scheduleId,
          'event_timestamp': DateTime.now().millisecondsSinceEpoch,
          'latitude': lat,
          'longitude': lng,
          'eta_updates': etaUpdates,
        }),
      );
    }
  }

  Future<void> sendAlert(String scheduleId, String alertType, String message) async {
    if (!_isOffline && _isLoggedIn) {
      final txnId = 'm${DateTime.now().millisecondsSinceEpoch}';
      final uri = Uri.parse('$_homeserver/_matrix/client/v3/rooms/$scheduleId/send/org.carpool.alert/$txnId');

      await _client.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: jsonEncode({
          'schedule_id': scheduleId,
          'event_timestamp': DateTime.now().millisecondsSinceEpoch,
          'alert_type': alertType,
          'message': message,
        }),
      );
    }
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _username = '';
    _accessToken = '';
    _deviceId = '';
    _syncToken = '';
    _devices = [];

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('matrix_access_token');
    await prefs.remove('matrix_username');
    await prefs.remove('matrix_device_id');
    await prefs.remove('matrix_sync_token');

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
          'initial_state': [
            {
              'type': 'm.room.encryption',
              'state_key': '',
              'content': {
                'algorithm': 'm.megolm.v1.aes-sha2',
              },
            },
          ],
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
