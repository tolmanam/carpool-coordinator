import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/services/matrix_service.dart';
import 'package:carpool_coordinator/services/background_streaming_service.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late DatabaseService dbService;
  late MatrixService matrixService;
  late BackgroundStreamingService streamingService;

  setUp(() async {
    dbService = DatabaseService();
    await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);

    final client = MockClient((request) async {
      if (request.url.path.contains('/_matrix/client/v3/pushers/set')) {
        return http.Response('{}', 200);
      }
      return http.Response('{}', 200);
    });

    matrixService = MatrixService(dbService: dbService, client: client);
    streamingService = BackgroundStreamingService(
      matrixService: matrixService,
      client: client,
    );
  });

  tearDown(() async {
    await streamingService.stopBackgroundLocationStreaming();
    await dbService.purgeAllData();
  });

  group('BackgroundStreamingService Unit Tests', () {
    test('Starts and stops background location streaming', () async {
      expect(streamingService.isBackgroundStreamingActive, false);
      expect(streamingService.activeScheduleId, null);

      await streamingService.startBackgroundLocationStreaming('schedule_test_101');

      expect(streamingService.isBackgroundStreamingActive, true);
      expect(streamingService.activeScheduleId, 'schedule_test_101');

      await streamingService.stopBackgroundLocationStreaming();

      expect(streamingService.isBackgroundStreamingActive, false);
      expect(streamingService.activeScheduleId, null);
    });

    test('Registers Matrix Push Gateway pusher successfully', () async {
      final success = await streamingService.registerPushGatewayPusher(
        pushkey: 'mock_pushkey_xyz123',
        appId: 'org.carpool.coordinator',
        appDisplayName: 'Carpool Coordinator App',
        deviceDisplayName: 'Pixel 8 Pro',
      );

      expect(success, true);
    });

    test('Dispatches high priority alert push notification', () async {
      await streamingService.sendHighPriorityAlertPushNotification(
        'schedule_test_101',
        'Severe Delay',
        'Driver delayed by 15 minutes due to heavy traffic',
      );

      final pendingEvents = await dbService.getPendingEvents();
      expect(pendingEvents.length, greaterThan(0));
      expect(pendingEvents.any((e) => (e['payload_json'] as String).contains('Severe Delay')), true);
    });
  });
}
