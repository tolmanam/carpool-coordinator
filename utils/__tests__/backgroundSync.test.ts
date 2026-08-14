import { mockMatrixCloud, fetchMatrixRoomState, sendMatrixStateEvent } from '../matrixClient';

// Mock expo native background tasks
jest.mock('expo-task-manager', () => ({
  defineTask: jest.fn(),
  isTaskRegisteredAsync: jest.fn(() => Promise.resolve(false)),
}));

jest.mock('expo-background-fetch', () => ({
  registerTaskAsync: jest.fn(),
  BackgroundFetchResult: {
    NoData: 'NoData',
    NewData: 'NewData',
    Failed: 'Failed',
  },
}));

import { performBackgroundSync, ICAL_SYNC_TASK } from '../backgroundSync';
import { db } from '../../db/client';

// Mock standard database client module
const mockDb = {
  select: jest.fn().mockReturnThis(),
  from: jest.fn().mockReturnThis(),
  where: jest.fn().mockReturnThis(),
  all: jest.fn(),
  get: jest.fn(),
  insert: jest.fn().mockReturnThis(),
  values: jest.fn().mockReturnThis(),
  onConflictDoUpdate: jest.fn().mockReturnThis(),
};

jest.mock('../../db/client', () => ({
  db: {
    select: (...args: any[]) => mockDb.select(...args),
    from: (...args: any[]) => mockDb.from(...args),
    where: (...args: any[]) => mockDb.where(...args),
    insert: (...args: any[]) => mockDb.insert(...args),
    values: (...args: any[]) => mockDb.values(...args),
    onConflictDoUpdate: (...args: any[]) => mockDb.onConflictDoUpdate(...args),
  },
}));

describe('Background iCal Sync Task and Locking Tests', () => {
  beforeEach(() => {
    jest.clearAllMocks();
    mockMatrixCloud.stateEvents = {};
    mockMatrixCloud.messages = {};
  });

  it('performs background sync and acquires a state lock if none exists', async () => {
    // 1. Mock DB returns a valid schedule
    mockDb.all
      .mockReturnValueOnce([
        {
          scheduleId: 'sched_test_123',
          title: 'Soccer Practice',
          icalFeedUrl: 'https://test-soccer.ics',
          latitude: 34.0,
          longitude: -118.0,
          addressText: 'Field A',
        },
      ]) // For cachedSchedules query
      .mockReturnValueOnce([]); // For localIcalEvents query

    // Mock username/homeserver settings inside getSessionInfo
    mockDb.get
      .mockReturnValueOnce({ value: 'alice_parent' }) // username
      .mockReturnValueOnce({ value: 'https://matrix.org' }) // homeserver
      .mockReturnValueOnce({ value: 'true' }); // isLoggedIn

    // 2. Perform Sync
    const result = await performBackgroundSync();

    // 3. Verify standard NewData result
    expect(result).toBe('NewData');

    // 4. Verify lock was successfully written to mockMatrixCloud
    const lockState = await fetchMatrixRoomState('sched_test_123', 'org.carpool.ical_lock');
    expect(lockState).not.toBeNull();
    expect(lockState.content.synced_by).toBe('@alice_parent:matrix.org');
    expect(lockState.content.last_sync_timestamp).toBeGreaterThan(0);
  });

  it('skips background sync if lock was recently acquired by another client', async () => {
    // 1. Pre-populate the mock matrix cloud state with a recent lock (less than 4 hours old)
    const fourHoursInMs = 4 * 60 * 60 * 1000;
    const recentTime = Date.now() - 30 * 60 * 1000; // 30 mins ago
    await sendMatrixStateEvent('sched_test_123', 'org.carpool.ical_lock', {
      last_sync_timestamp: recentTime,
      synced_by: '@bob:matrix.org',
    });

    // Mock DB return schedules
    mockDb.all.mockReturnValueOnce([
      {
        scheduleId: 'sched_test_123',
        title: 'Soccer Practice',
        icalFeedUrl: 'https://test-soccer.ics',
      },
    ]);

    // Mock username/homeserver settings inside getSessionInfo
    mockDb.get
      .mockReturnValueOnce({ value: 'alice_parent' }) // username
      .mockReturnValueOnce({ value: 'https://matrix.org' }) // homeserver
      .mockReturnValueOnce({ value: 'true' }); // isLoggedIn

    // 2. Perform Sync
    const result = await performBackgroundSync();

    // 3. Verify it skipped and returned NoData
    expect(result).toBe('NoData');

    // 4. Verify the lock has not been overwritten by Alice
    const lockState = await fetchMatrixRoomState('sched_test_123', 'org.carpool.ical_lock');
    expect(lockState.content.synced_by).toBe('@bob:matrix.org');
  });

  it('acquires the lock if the existing lock has expired (> 4 hours)', async () => {
    // 1. Pre-populate the mock matrix cloud with an expired lock (e.g. 5 hours ago)
    const fiveHoursAgo = Date.now() - 5 * 60 * 60 * 1000;
    await sendMatrixStateEvent('sched_test_123', 'org.carpool.ical_lock', {
      last_sync_timestamp: fiveHoursAgo,
      synced_by: '@bob:matrix.org',
    });

    mockDb.all
      .mockReturnValueOnce([
        {
          scheduleId: 'sched_test_123',
          title: 'Soccer Practice',
          icalFeedUrl: 'https://test-soccer.ics',
        },
      ])
      .mockReturnValueOnce([]);

    // Mock username/homeserver settings inside getSessionInfo
    mockDb.get
      .mockReturnValueOnce({ value: 'alice_parent' }) // username
      .mockReturnValueOnce({ value: 'https://matrix.org' }) // homeserver
      .mockReturnValueOnce({ value: 'true' }); // isLoggedIn

    // 2. Perform Sync
    const result = await performBackgroundSync();

    // 3. Verify it ran and returned NewData
    expect(result).toBe('NewData');

    // 4. Verify lock was successfully acquired/overwritten by Alice
    const lockState = await fetchMatrixRoomState('sched_test_123', 'org.carpool.ical_lock');
    expect(lockState.content.synced_by).toBe('@alice_parent:matrix.org');
    expect(lockState.content.last_sync_timestamp).toBeGreaterThan(fiveHoursAgo);
  });
});
