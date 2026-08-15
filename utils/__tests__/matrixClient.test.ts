import {
  authenticateMatrix,
  getSessionInfo,
  logoutMatrix,
  createCircle,
  inviteMember,
  registerSignup,
  removeSignup,
  syncIcalFeed,
  markRoomAsCarpool,
  isCarpoolRoom,
  isValidCarpoolMessage,
  filterCarpoolMessages,
} from '../matrixClient';
import { db } from '../../db/client';

// Prepare a mock database query builder
const mockDb = {
  insert: jest.fn().mockReturnThis(),
  values: jest.fn().mockReturnThis(),
  onConflictDoUpdate: jest.fn().mockReturnThis(),
  onConflictDoNothing: jest.fn().mockReturnThis(),
  select: jest.fn().mockReturnThis(),
  from: jest.fn().mockReturnThis(),
  where: jest.fn().mockReturnThis(),
  get: jest.fn(),
  all: jest.fn(),
  delete: jest.fn().mockReturnThis(),
  update: jest.fn().mockReturnThis(),
  set: jest.fn().mockReturnThis(),
};

// Mock standard database client module
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

describe('Matrix Client Help Module Integration Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('authenticates a Matrix user and stores credentials & default profiles locally', async () => {
    await authenticateMatrix('alice', 'https://matrix.org');

    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      key: 'homeserver',
      value: 'https://matrix.org',
    }));
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      key: 'username',
      value: 'alice',
    }));
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      key: 'is_logged_in',
      value: 'true',
    }));
  });

  it('fetches session info', async () => {
    mockDb.get
      .mockReturnValueOnce({ value: 'alice' })        // username
      .mockReturnValueOnce({ value: 'https://matrix.org' }) // homeserver
      .mockReturnValueOnce({ value: 'true' });        // is_logged_in

    const session = await getSessionInfo();

    expect(session.isLoggedIn).toBe(true);
    expect(session.username).toBe('alice');
    expect(session.homeserver).toBe('https://matrix.org');
  });

  it('logs out and updates settings in local DB', async () => {
    await logoutMatrix();

    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      key: 'is_logged_in',
      value: 'false',
    }));
  });

  it('creates coordination circle and inserts schedule metadata', async () => {
    const id = await createCircle('Santa Monica Football Group');

    expect(id).toMatch(/^sched_/);
    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      title: 'Santa Monica Football Group',
    }));
  });

  it('invites a new member by saving family profiles and member placeholders', async () => {
    await inviteMember('sched_123', 'bob');

    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      familyName: 'bob Family',
    }));
  });

  it('registers and handles signups for riders and drivers', async () => {
    await registerSignup({
      scheduleId: 'sched_123',
      eventTimestamp: 10002000,
      memberId: 'child_1',
      role: 'rider',
      status: 'scheduled',
    });

    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      scheduleId: 'sched_123',
      eventTimestamp: 10002000,
      memberId: 'child_1',
      role: 'rider',
      status: 'scheduled',
    }));
  });

  it('allows removing signup instances', async () => {
    await removeSignup('sched_123', 10002000, 'child_1');

    expect(mockDb.delete).toHaveBeenCalled();
  });

  it('syncs standard lookahead calendar occurrences from parsed iCal strings', async () => {
    // Return mock schedule on DB query
    mockDb.get.mockReturnValueOnce({
      scheduleId: 'sched_123',
      title: 'Practice',
      icalFeedUrl: 'https://test.ics',
    });

    const mockIcs = `BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:evt_1
DTSTART:20261024T160000Z
DTEND:20261024T173000Z
SUMMARY:Unit Test Soccer Practice
END:VEVENT
END:VCALENDAR`;

    await syncIcalFeed('sched_123', mockIcs);

    // Should query schedule first
    expect(mockDb.select).toHaveBeenCalled();

    // Should insertparsed event
    expect(mockDb.insert).toHaveBeenCalled();
    expect(mockDb.values).toHaveBeenCalledWith(expect.objectContaining({
      title: 'Unit Test Soccer Practice',
    }));
  });

  it('correctly identifies and marks Carpool Matrix rooms', async () => {
    const roomId = 'room_test_carpool_tag';

    expect(await isCarpoolRoom(roomId)).toBe(false);

    await markRoomAsCarpool(roomId);

    expect(await isCarpoolRoom(roomId)).toBe(true);
  });

  it('validates structured org.carpool messages and filters out invalid or hand-typed chat messages', () => {
    const validSignup = {
      type: 'org.carpool.signup',
      content: {
        schedule_id: 'sched_1',
        event_timestamp: 1698393600000,
        member_id: 'child_1',
        role: 'rider',
        status: 'scheduled',
      },
    };

    const validLocation = {
      type: 'org.carpool.location',
      content: {
        schedule_id: 'sched_1',
        latitude: 34.05,
        longitude: -118.25,
      },
    };

    const handTypedMessage = {
      type: 'm.room.message',
      content: {
        msgtype: 'm.text',
        body: 'Hello everyone! Is anyone driving today?',
      },
    };

    const malformedSignup = {
      type: 'org.carpool.signup',
      content: {
        schedule_id: 'sched_1',
        // missing event_timestamp and member_id
      },
    };

    expect(isValidCarpoolMessage(validSignup)).toBe(true);
    expect(isValidCarpoolMessage(validLocation)).toBe(true);
    expect(isValidCarpoolMessage(handTypedMessage)).toBe(false);
    expect(isValidCarpoolMessage(malformedSignup)).toBe(false);

    const filtered = filterCarpoolMessages([validSignup, handTypedMessage, validLocation, malformedSignup]);
    expect(filtered).toHaveLength(2);
    expect(filtered).toEqual([validSignup, validLocation]);
  });
});
