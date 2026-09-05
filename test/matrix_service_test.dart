import 'package:flutter_test/flutter_test.dart';
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
  });
}
