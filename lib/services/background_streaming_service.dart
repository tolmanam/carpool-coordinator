import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'matrix_service.dart';

/// Service managing background GPS location streaming and Matrix Push Gateway notifications.
class BackgroundStreamingService extends ChangeNotifier {
  final MatrixService matrixService;
  final http.Client _client;

  bool _isBackgroundStreamingActive = false;
  String? _activeScheduleId;
  Timer? _streamingTimer;
  int _updateIntervalSeconds = 10;

  bool get isBackgroundStreamingActive => _isBackgroundStreamingActive;
  String? get activeScheduleId => _activeScheduleId;

  BackgroundStreamingService({
    required this.matrixService,
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Starts background GPS location streaming for an active drive schedule.
  Future<void> startBackgroundLocationStreaming(
    String scheduleId, {
    int updateIntervalSeconds = 10,
    double initialLat = 34.0522,
    double initialLng = -118.2437,
  }) async {
    _activeScheduleId = scheduleId;
    _updateIntervalSeconds = updateIntervalSeconds;
    _isBackgroundStreamingActive = true;

    // Send initial location update
    await matrixService.sendLocation(scheduleId, initialLat, initialLng, []);

    _streamingTimer?.cancel();
    _streamingTimer = Timer.periodic(
      Duration(seconds: _updateIntervalSeconds),
      (timer) async {
        if (!_isBackgroundStreamingActive || _activeScheduleId == null) {
          timer.cancel();
          return;
        }

        // Simulated background GPS coordinate progression
        final currentLat = initialLat + (timer.tick * 0.0001);
        final currentLng = initialLng + (timer.tick * 0.0001);

        await matrixService.sendLocation(
          _activeScheduleId!,
          currentLat,
          currentLng,
          [
            {
              'waypoint_id': 'waypoint_next',
              'eta_timestamp': DateTime.now().add(const Duration(minutes: 15)).millisecondsSinceEpoch,
            }
          ],
        );
        notifyListeners();
      },
    );

    notifyListeners();
  }

  /// Stops active background GPS location streaming.
  Future<void> stopBackgroundLocationStreaming() async {
    _isBackgroundStreamingActive = false;
    _streamingTimer?.cancel();
    _streamingTimer = null;
    _activeScheduleId = null;
    notifyListeners();
  }

  /// Registers a Matrix Push Gateway pusher (`/_matrix/client/v3/pushers/set`).
  Future<bool> registerPushGatewayPusher({
    required String pushkey,
    required String appId,
    required String appDisplayName,
    required String deviceDisplayName,
    String gatewayUrl = 'https://matrix.org/_matrix/push/v1/notify',
  }) async {
    if (matrixService.isOffline || !matrixService.isLoggedIn) {
      debugPrint('BackgroundStreamingService: Offline or not logged in. Mocking pusher registration.');
      return true;
    }

    try {
      final uri = Uri.parse('${matrixService.homeserver}/_matrix/client/v3/pushers/set');
      final response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${matrixService.accessToken}',
        },
        body: jsonEncode({
          'pushkey': pushkey,
          'kind': 'http',
          'app_id': appId,
          'app_display_name': appDisplayName,
          'device_display_name': deviceDisplayName,
          'profile_tag': 'carpool_active_route',
          'lang': 'en',
          'data': {
            'url': gatewayUrl,
            'format': 'event_id_only',
          },
          'append': false,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error registering Matrix Push Gateway pusher: $e');
      return false;
    }
  }

  /// Dispatches high-priority push notification alert via Push Gateway.
  Future<void> sendHighPriorityAlertPushNotification(
    String scheduleId,
    String title,
    String alertMessage,
  ) async {
    await matrixService.sendAlert(
      scheduleId,
      'urgent_push_alert',
      '$title: $alertMessage',
    );
  }
}
