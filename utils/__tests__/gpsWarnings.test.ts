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

import { processActiveGpsTick, mockMatrixCloud } from '../matrixClient';
import { recalculateWaypointsEta, Waypoint } from '../routeOptimizer';

describe('GPS Location Ticks & Late-Arrival Delay Warnings', () => {
  const scheduleId = 'sched_soccer_123';
  const eventTimestamp = 1799846400000; // Future date

  beforeEach(() => {
    mockMatrixCloud.messages = {};
    mockMatrixCloud.stateEvents = {};
  });

  test('recalculateWaypointsEta computes chronological ETAs based on speed and distance', () => {
    const currentLocation = { latitude: 34.0194, longitude: -118.4912 }; // Santa Monica
    const waypoints: Waypoint[] = [
      {
        type: 'pickup',
        latitude: 34.0250,
        longitude: -118.4700, // Connor home (approx 2.1km away)
        memberId: 'child_1',
      },
      {
        type: 'destination',
        latitude: 34.0415,
        longitude: -118.4520, // Clover Park (approx 2.5km from Connor)
      },
    ];

    const updated = recalculateWaypointsEta(currentLocation, waypoints, 30); // 30 km/h

    expect(updated).toHaveLength(2);
    // Pickup stop is calculated first
    expect(updated[0].estimatedTime).toBeGreaterThan(Date.now());
    // Destination stop is calculated after pickup stop
    expect(updated[1].estimatedTime).toBeGreaterThan(updated[0].estimatedTime!);
  });

  test('processActiveGpsTick broadcasts location coordinates and computes ETAs', async () => {
    const currentLocation = { latitude: 34.0194, longitude: -118.4912 };
    const waypoints: Waypoint[] = [
      {
        type: 'pickup',
        latitude: 34.0250,
        longitude: -118.4700,
        memberId: 'child_1',
        originalScheduledTime: Date.now() + 5 * 60 * 1000, // 5 min from now
      },
    ];

    await processActiveGpsTick(currentLocation, waypoints, scheduleId, eventTimestamp);

    const roomMsgs = mockMatrixCloud.messages[scheduleId];
    expect(roomMsgs).toBeDefined();

    // There should be a location stream broadcast
    const locMsg = roomMsgs.find(m => m.type === 'org.carpool.location');
    expect(locMsg).toBeDefined();
    expect(locMsg.content.latitude).toBe(currentLocation.latitude);
    expect(locMsg.content.longitude).toBe(currentLocation.longitude);
    expect(locMsg.content.eta_updates).toHaveLength(1);
  });

  test('processActiveGpsTick dispatches delay alert if driver runs more than 5 minutes late', async () => {
    const currentLocation = { latitude: 34.0194, longitude: -118.4912 };

    // Simulate that pickup originally was planned very soon (e.g. 5 minutes ago)
    // but the calculated ETA based on current coordinates makes us 8 minutes late.
    const originalTime = Date.now() - 5 * 60 * 1000;

    const waypoints: Waypoint[] = [
      {
        type: 'pickup',
        latitude: 34.0250,
        longitude: -118.4700,
        memberId: 'child_1',
        originalScheduledTime: originalTime, // Planned 5 min ago
        // Let's pass estimatedTime that exceeds originalTime by 8 mins to trigger delay warning
        estimatedTime: originalTime + 8 * 60 * 1000,
      },
    ];

    await processActiveGpsTick(currentLocation, waypoints, scheduleId, eventTimestamp);

    const roomMsgs = mockMatrixCloud.messages[scheduleId];
    expect(roomMsgs).toBeDefined();

    // Verify delay alert was triggered & posted
    const alertMsg = roomMsgs.find(m => m.type === 'org.carpool.alert');
    expect(alertMsg).toBeDefined();
    expect(alertMsg.content.alert_type).toBe('delay');
    expect(alertMsg.content.severity).toBe('warning');
    expect(alertMsg.content.message).toContain('running approx');
  });
});
