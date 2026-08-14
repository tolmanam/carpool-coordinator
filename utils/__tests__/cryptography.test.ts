jest.mock('expo-sqlite', () => ({
  openDatabaseSync: jest.fn(() => ({
    execSync: jest.fn(),
  })),
}));

jest.mock('expo-secure-store', () => {
  const store: Record<string, string> = {};
  return {
    getItemAsync: jest.fn(async (key: string) => store[key] || null),
    setItemAsync: jest.fn(async (key: string, value: string) => {
      store[key] = value;
      return null;
    }),
  };
});

import { getOrCreateDbKey } from '../../db/client';
import {
  activateRoomE2EE,
  isRoomE2eeActive,
  encryptPayloadE2EE,
  decryptPayloadE2EE,
} from '../matrixClient';
import * as SecureStore from 'expo-secure-store';

describe('Progressive Cryptography & Security Controls Tests', () => {
  const roomId = 'sched_e2ee_room_123';

  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('Secure SQL Storage Key Derivation', () => {
    it('generates and stores a secure database encryption key if none exists', async () => {
      const key = await getOrCreateDbKey();

      expect(key).toContain('sec_key_');
      expect(SecureStore.getItemAsync).toHaveBeenCalledWith('db_encryption_key');
      expect(SecureStore.setItemAsync).toHaveBeenCalledWith('db_encryption_key', key);
    });

    it('returns the existing database encryption key if it exists', async () => {
      // Seed key
      await SecureStore.setItemAsync('db_encryption_key', 'existing_key_abc_123');
      jest.clearAllMocks();

      const key = await getOrCreateDbKey();

      expect(key).toBe('existing_key_abc_123');
      expect(SecureStore.getItemAsync).toHaveBeenCalledWith('db_encryption_key');
      expect(SecureStore.setItemAsync).not.toHaveBeenCalled();
    });
  });

  describe('Matrix Olm/Megolm E2EE Simulation', () => {
    it('activates E2EE and establishes a Megolm session key', async () => {
      let isEncr = await isRoomE2eeActive(roomId);
      expect(isEncr).toBe(false);

      await activateRoomE2EE(roomId);

      isEncr = await isRoomE2eeActive(roomId);
      expect(isEncr).toBe(true);
    });

    it('encrypts and decrypts communication payloads using base64 Megolm envelope simulation', async () => {
      await activateRoomE2EE(roomId);

      const secretPayload = {
        member_id: 'child_connor',
        role: 'rider',
        address: '734 Ocean Avenue, Santa Monica',
      };

      // Encrypt
      const encrypted = encryptPayloadE2EE(roomId, secretPayload);
      expect(encrypted).toHaveProperty('algorithm', 'm.megolm.v1.aes-sha2');
      expect(encrypted).toHaveProperty('ciphertext');
      expect(encrypted.ciphertext).not.toBe(JSON.stringify(secretPayload));

      // Decrypt
      const decrypted = decryptPayloadE2EE(roomId, encrypted);
      expect(decrypted).toEqual(secretPayload);
    });

    it('returns unencrypted payload if room encryption key is not activated', () => {
      const plainPayload = { test: 'unencrypted' };
      const nonE2eeRoom = 'room_public_999';

      const encrypted = encryptPayloadE2EE(nonE2eeRoom, plainPayload);
      expect(encrypted).toEqual(plainPayload);

      const decrypted = decryptPayloadE2EE(nonE2eeRoom, encrypted);
      expect(decrypted).toEqual(plainPayload);
    });
  });
});
