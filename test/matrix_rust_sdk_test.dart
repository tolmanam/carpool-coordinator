import 'package:flutter_test/flutter_test.dart';
import 'package:carpool_coordinator/services/matrix_rust_sdk_binding.dart';

void main() {
  group('MatrixRustSdkBinding Unit Tests', () {
    test('Initialization creates session key and initializes binding', () async {
      final binding = MatrixRustSdkBinding(
        homeserver: 'https://matrix.org',
        userId: '@user:matrix.org',
        deviceId: 'DEVICE_TEST_1',
      );

      expect(binding.isInitialized, false);
      expect(binding.sessionKey, null);

      final success = await binding.initializeSession();

      expect(success, true);
      expect(binding.isInitialized, true);
      expect(binding.sessionKey, isNotNull);
      expect(binding.sessionKey!.contains('megolm_session_'), true);
    });

    test('Encrypt and decrypt payload roundtrip', () async {
      final binding = MatrixRustSdkBinding(
        homeserver: 'https://matrix.org',
        userId: '@user:matrix.org',
        deviceId: 'DEVICE_TEST_1',
      );

      await binding.initializeSession();

      const plainText = 'Hello E2EE Matrix Room!';
      final encrypted = await binding.encryptPayload('!room123:matrix.org', plainText);

      expect(encrypted['algorithm'], 'm.megolm.v1.aes-sha2');
      expect(encrypted['ciphertext'], isNotNull);
      expect(encrypted['room_id'], '!room123:matrix.org');

      final decrypted = await binding.decryptPayload(encrypted);
      expect(decrypted, plainText);
    });

    test('Generate device keys payload formats correctly', () {
      final binding = MatrixRustSdkBinding(
        homeserver: 'https://matrix.org',
        userId: '@user:matrix.org',
        deviceId: 'DEVICE_TEST_1',
      );

      final payload = binding.generateDeviceKeysPayload();

      expect(payload['user_id'], '@user:matrix.org');
      expect(payload['device_id'], 'DEVICE_TEST_1');
      expect(payload['algorithms'], contains('m.megolm.v1.aes-sha2'));
      expect(payload['keys'], contains('curve25519:DEVICE_TEST_1'));
      expect(payload['keys'], contains('ed25519:DEVICE_TEST_1'));
    });
  });
}
