import {
  authenticateMatrix,
  reauthenticateAndClearCache,
  setNotificationSound,
  getNotificationSound,
  setThemeMode,
  getThemeMode,
  updateUserProfileRoles,
  getUserProfileRoles,
  isUserParent,
  updateFamilyName,
  addFamilyMember,
  removeFamilyMember,
  createCarpoolGroup,
  updateGroupEventSources,
  addParticipantFamily,
  removeParticipantFamily,
  fetchMatrixRoomState,
} from '../matrixClient';

// Mock database query builder for Jest environment
const mockDb = {
  insert: jest.fn().mockReturnThis(),
  values: jest.fn().mockReturnThis(),
  onConflictDoUpdate: jest.fn().mockReturnThis(),
  onConflictDoNothing: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  from: jest.fn().mockReturnThis(),
  where: jest.fn().mockReturnThis(),
  get: jest.fn(),
  all: jest.fn().mockReturnValue([]),
  delete: jest.fn().mockReturnThis(),
  update: jest.fn().mockReturnThis(),
  set: jest.fn().mockReturnThis(),
};

jest.mock('../../db/client', () => ({
  db: {
    insert: (...args: any[]) => mockDb.insert(...args),
    values: (...args: any[]) => mockDb.values(...args),
    onConflictDoUpdate: (...args: any[]) => mockDb.onConflictDoUpdate(...args),
    onConflictDoNothing: (...args: any[]) => mockDb.onConflictDoNothing(...args),
    select: (...args: any[]) => mockDb.select(...args),
    from: (...args: any[]) => mockDb.from(...args),
    where: (...args: any[]) => mockDb.where(...args),
    delete: (...args: any[]) => mockDb.delete(...args),
    update: (...args: any[]) => mockDb.update(...args),
    set: (...args: any[]) => mockDb.set(...args),
  },
}));

describe('Configuration Features & Business Logic', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  describe('1. System Configuration', () => {
    test('Notification Sound and Theme Mode persist to local settings', async () => {
      await setNotificationSound('chime');
      expect(mockDb.insert).toHaveBeenCalled();
      expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
        key: 'notification_sound',
        value: 'chime',
      }));

      mockDb.get.mockReturnValueOnce({ value: 'chime' });
      expect(await getNotificationSound()).toBe('chime');

      await setThemeMode('dark');
      expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
        key: 'theme_mode',
        value: 'dark',
      }));

      mockDb.get.mockReturnValueOnce({ value: 'dark' });
      expect(await getThemeMode()).toBe('dark');
    });

    test('reauthenticateAndClearCache clears cached data tables and re-logins', async () => {
      mockDb.get.mockImplementation(() => {
        return { value: 'default' };
      });

      await reauthenticateAndClearCache('bob_new_user', 'https://matrix.example.com');

      expect(mockDb.delete).toHaveBeenCalled();
      expect(mockDb.insert).toHaveBeenCalledWith(expect.anything());
    });
  });

  describe('2. Profile Configuration', () => {
    test('updateUserProfileRoles saves multi-select roles and broadcasts Matrix state event', async () => {
      mockDb.get.mockImplementation(() => ({ value: 'alice' }));
      const roles = ['Parent', 'Driver', 'Participant'];

      await updateUserProfileRoles(roles);

      expect(mockDb.insert).toHaveBeenCalled();
      expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
        role: JSON.stringify(roles),
      }));

      // Check broadcasted state event
      const stateEvent = await fetchMatrixRoomState('@alice:matrix.org', 'org.carpool.family.profile');
      expect(stateEvent).not.toBeNull();
      expect(stateEvent.content.roles).toEqual(roles);
    });

    test('isUserParent returns true when Parent role exists', async () => {
      let callCount = 0;
      mockDb.get.mockImplementation(() => {
        callCount++;
        if (callCount <= 3) return { value: 'alice' };
        return { role: JSON.stringify(['Parent', 'Driver']) };
      });

      expect(await isUserParent()).toBe(true);
    });
  });

  describe('3. Family Group Configuration', () => {
    test('updateFamilyName updates DB and broadcasts state event', async () => {
      mockDb.get.mockReturnValue({ value: 'alice' });
      await updateFamilyName('The Awesome Builders');

      expect(mockDb.update).toHaveBeenCalled();
      expect(mockDb.set).toHaveBeenCalledWith(expect.objectContaining({
        familyName: 'The Awesome Builders',
      }));

      const stateEvent = await fetchMatrixRoomState('@alice:matrix.org', 'org.carpool.family.profile');
      expect(stateEvent.content.family_name).toBe('The Awesome Builders');
    });

    test('addFamilyMember and removeFamilyMember invoke DB operations', async () => {
      mockDb.get.mockReturnValue({ value: 'alice' });
      const memberId = await addFamilyMember('Tommy', ['Participant']);

      expect(memberId).toMatch(/^mem_/);
      expect(mockDb.insert).toHaveBeenCalled();

      await removeFamilyMember(memberId);
      expect(mockDb.delete).toHaveBeenCalled();
    });
  });

  describe('4. Carpool Group Configuration', () => {
    test('createCarpoolGroup succeeds for Parents and sets group metadata', async () => {
      mockDb.get.mockImplementation(() => {
        return { role: JSON.stringify(['Parent']), value: 'alice' };
      });

      const scheduleId = await createCarpoolGroup('Swim Club Commute', ['https://calendar.org/feed1.ics']);

      expect(scheduleId).toMatch(/^sched_/);
      expect(mockDb.insert).toHaveBeenCalled();
      expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
        title: 'Swim Club Commute',
        ownerId: '@alice:matrix.org',
      }));
    });

    test('createCarpoolGroup throws error if user is not a Parent', async () => {
      mockDb.get.mockImplementation(() => {
        return { role: JSON.stringify(['Participant']), value: 'alice' };
      });

      await expect(createCarpoolGroup('Non Parent Group')).rejects.toThrow('Only users with the Parent role can create Carpool Groups.');
    });

    test('updateGroupEventSources updates event sources for owner', async () => {
      mockDb.get.mockImplementation(() => {
        return {
          value: 'alice',
          scheduleId: 'sched_1',
          ownerId: '@alice:matrix.org',
          eventSourcesJson: JSON.stringify(['https://calendar.org/feed1.ics']),
        };
      });

      await updateGroupEventSources('sched_1', ['https://calendar.org/feed1.ics', 'https://calendar.org/feed2.ics']);

      expect(mockDb.update).toHaveBeenCalled();
      expect(mockDb.set).toHaveBeenCalledWith(expect.objectContaining({
        eventSourcesJson: JSON.stringify(['https://calendar.org/feed1.ics', 'https://calendar.org/feed2.ics']),
      }));
    });

    test('addParticipantFamily and removeParticipantFamily update participants json', async () => {
      mockDb.get.mockImplementation(() => {
        return {
          value: 'alice',
          scheduleId: 'sched_1',
          ownerId: '@alice:matrix.org',
          participantsJson: JSON.stringify(['@alice:matrix.org']),
        };
      });

      await addParticipantFamily('sched_1', '@charlie_family:matrix.org');
      expect(mockDb.update).toHaveBeenCalled();

      await removeParticipantFamily('sched_1', '@charlie_family:matrix.org');
      expect(mockDb.update).toHaveBeenCalled();
    });
  });
});
