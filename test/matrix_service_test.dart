import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:carpool_coordinator/services/database_service.dart';
import 'package:carpool_coordinator/services/matrix_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  group('Matrix Device Validation & Sync Loop Unit Tests', () {
    late DatabaseService dbService;
    late MatrixService matrixService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      dbService = DatabaseService();
      await dbService.initDatabase(inMemoryPath: inMemoryDatabasePath);
      matrixService = MatrixService(dbService: dbService);
    });

    test('Matrix device loading and device verification status update', () async {
      matrixService.toggleOfflineMode(true);
      await matrixService.login('alice', 'password123');

      expect(matrixService.isLoggedIn, isTrue);
      expect(matrixService.deviceId, equals('OFFLINE_DEVICE_1'));

      expect(matrixService.devices.isNotEmpty, isTrue);
      expect(matrixService.devices.first.verificationStatus, equals('Verified'));

      // Verify status toggle
      await matrixService.verifyDevice('OFFLINE_DEVICE_1', 'Blocked');
      expect(matrixService.devices.first.verificationStatus, equals('Blocked'));

      await matrixService.verifyDevice('OFFLINE_DEVICE_1', 'Verified');
      expect(matrixService.devices.first.verificationStatus, equals('Verified'));
    });

    test('Matrix custom carpool event dispatching updates database', () async {
      matrixService.toggleOfflineMode(true);
      await matrixService.login('alice', 'password123');

      final scheduleId = await matrixService.createCircle('Test Matrix Circle');
      final now = DateTime.now().millisecondsSinceEpoch;

      await matrixService.sendSignup(scheduleId, 'child_1', 'rider', 'scheduled', now);

      final signups = await dbService.getSignups(scheduleId);
      expect(signups.length, equals(1));
      expect(signups.first.memberId, equals('child_1'));
      expect(signups.first.role, equals('rider'));
    });

    test('Homeserver well-known auto-discovery returns base_url', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/.well-known/matrix/client') {
          return http.Response(
            jsonEncode({
              'm.homeserver': {'base_url': 'https://custom.matrix.server'}
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = MatrixService(dbService: dbService, client: mockClient);
      final discovered = await service.discoverHomeserver('example.com');
      expect(discovered, equals('https://custom.matrix.server'));
    });

    test('Homeserver well-known discovery falls back on error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = MatrixService(dbService: dbService, client: mockClient);
      final discovered = await service.discoverHomeserver('example.com');
      expect(discovered, equals('https://example.com'));
    });

    test('Sync handles 401 Unauthorized by logging out user', () async {
      bool isSyncCall = false;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/.well-known/matrix/client') {
          return http.Response(
            jsonEncode({
              'm.homeserver': {'base_url': 'https://matrix.org'}
            }),
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/login') {
          return http.Response(
            jsonEncode({
              'access_token': 'mock_token',
              'user_id': '@alice:matrix.org',
              'device_id': 'DEV1',
            }),
            200,
          );
        }
        if (request.url.path == '/_matrix/client/v3/keys/upload') {
          return http.Response(jsonEncode({'one_time_key_counts': {}}), 200);
        }
        if (request.url.path == '/_matrix/client/v3/devices') {
          return http.Response(jsonEncode({'devices': []}), 200);
        }
        if (request.url.path.contains('/_matrix/client/v3/sync')) {
          if (!isSyncCall) {
            // First sync during login succeeds
            isSyncCall = true;
            return http.Response(jsonEncode({'next_batch': 'batch_1'}), 200);
          }
          // Subsequent sync fails with 401
          return http.Response(
            jsonEncode({
              'errcode': 'M_UNKNOWN_TOKEN',
              'error': 'Unrecognised access token',
            }),
            401,
          );
        }
        return http.Response('{}', 200);
      });

      final service = MatrixService(dbService: dbService, client: mockClient);
      await service.login('alice', 'password123', homeserverUrl: 'https://matrix.org');
      expect(service.isLoggedIn, isTrue);

      await service.syncJoinedRooms();
      expect(service.isLoggedIn, isFalse);
    });

    test('Exponential backoff calculation doubles until max cap', () {
      expect(matrixService.calculateBackoff(0), equals(2000));
      expect(matrixService.calculateBackoff(2000), equals(4000));
      expect(matrixService.calculateBackoff(4000), equals(8000));
      expect(matrixService.calculateBackoff(32000), equals(60000));
      expect(matrixService.calculateBackoff(60000), equals(60000));
    });
  });
}
