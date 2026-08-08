# Client-Side Flows & Internal APIs - Carpool Coordinator

This document specifies the internal module contracts, background task interfaces, and the routing/TSP engine logic running client-side.

---

## 1. Matrix Authentication & Room Setup Flows

Since this is a decentralized, serverless model, we interface directly with the user's selected Matrix homeserver.

```typescript
export interface MatrixClientConfig {
  baseUrl: string;
  userId: string;
  accessToken: string;
}

/**
 * Initializes the local client Matrix SDK and starts the event synchronization loop.
 */
export async function initializeMatrixSession(config: MatrixClientConfig): Promise<void> {
  // 1. Instantiates standard Matrix Client SDK
  // 2. Begins Matrix /sync background execution loop
  // 3. Registers Matrix Event listeners to intercept custom 'org.carpool.*' namespaces
}

/**
 * Sets up a private, end-to-end encrypted Matrix Room for a new carpool circle.
 */
export async function createCarpoolCircle(roomName: string): Promise<string> {
  const payload = {
    preset: "private_chat",
    name: roomName,
    topic: "Shared family carpool coordination circle",
    initial_state: [
      {
        type: "m.room.encryption",
        state_key: "",
        content: {
          algorithm: "m.megolm.v1.aes-sha2"
        }
      }
    ]
  };

  // POST /_matrix/client/v3/createRoom
  // Returns roomId
}
```

---

## 2. iCal Parsing & Distributed Synchronization Worker

We implement a background worker utilizing `expo-task-manager` and `expo-background-fetch` that executes every 4–6 hours to pull updated calendars.

```typescript
import * as TaskManager from 'expo-task-manager';
import * as BackgroundFetch from 'expo-background-fetch';

export const ICAL_SYNC_TASK = 'BACKGROUND_ICAL_SYNC_TASK';

/**
 * The task runner called by the OS background daemon.
 * Implements the decentralized state-locking algorithm to divide scraping duty.
 */
TaskManager.defineTask(ICAL_SYNC_TASK, async () => {
  try {
    const schedules = await db.select().from(cachedSchedules);

    for (const schedule of schedules) {
      // 1. Query the current Matrix State Event 'org.carpool.ical_lock' for this scheduleId
      const currentLock = await fetchMatrixRoomState(schedule.scheduleId, 'org.carpool.ical_lock');

      const lastSync = currentLock?.content?.last_sync_timestamp || 0;
      const fourHoursInMs = 4 * 60 * 60 * 1000;

      // If synced recently by another client, skip to prevent API rate limits
      if (Date.now() - lastSync < AmphoraSyncInterval) {
        continue;
      }

      // 2. Fetch Lock Attempt: Post updated lock with current client metadata
      await sendMatrixStateEvent(schedule.scheduleId, 'org.carpool.ical_lock', {
        last_sync_timestamp: Date.now(),
        synced_by: currentUserId,
        ical_feed_url: schedule.icalFeedUrl,
      });

      // 3. Fetch external .ics payload
      const response = await fetch(schedule.icalFeedUrl);
      const icsString = await response.text();

      // 4. Client-side parse iCal calendar
      const occurrences = parseIcalString(icsString, schedule.scheduleId);

      // 5. Update Local SQLite Index with new, altered, or deleted calendar dates
      await reconcileLocalDatabaseEvents(schedule.scheduleId, occurrences);

      // 6. Push updated occurrences to Matrix room state 'org.carpool.schedules'
      await sendMatrixStateEvent(schedule.scheduleId, 'org.carpool.schedules', {
        title: schedule.title,
        ical_feed_url: schedule.icalFeedUrl,
        destination: {
          latitude: schedule.latitude,
          longitude: schedule.longitude,
          address_text: schedule.addressText
        },
        parsed_events: occurrences // Store current lookahead occurrences list directly in State
      });
    }

    return BackgroundFetch.BackgroundFetchResult.NewData;
  } catch (error) {
    console.error("Background sync failure:", error);
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
});
```

---

## 3. Client-Side Route Optimizer (TSP Solver)

The assigned driver's client runs a Traveling Salesperson Problem (TSP) solver locally to plan optimal routing waypoints and times.

```typescript
export interface Waypoint {
  memberId?: string; // Optional, empty for target Destination point
  type: 'driver_start' | 'pickup' | 'destination';
  latitude: number;
  longitude: number;
  estimatedTime?: number;
}

/**
 * Solves TSP using a Greedy Nearest Neighbor heuristic.
 * Perfect for typical carpools (<10 addresses) to avoid battery drain or paid APIs.
 */
export function solveOptimalRoute(
  driverHome: { latitude: number; longitude: number; memberId: string },
  destination: { latitude: number; longitude: number },
  riderAddresses: Array<{ latitude: number; longitude: number; memberId: string }>,
  targetArrivalTime: number, // Unix Timestamp
  averageSpeedKph: number = 30 // Typical urban driving velocity
): Waypoint[] {

  let unvisited = [...riderAddresses];
  let currentLoc = { ...driverHome };
  const route: Waypoint[] = [
    { memberId: driverHome.memberId, type: 'driver_start', latitude: driverHome.latitude, longitude: driverHome.longitude }
  ];

  // 1. Solve order by finding nearest neighbor incrementally
  while (unvisited.length > 0) {
    let nearestIdx = 0;
    let minDistance = Infinity;

    for (let i = 0; i < unvisited.length; i++) {
      const dist = calculateHaversineDistance(
        currentLoc.latitude,
        currentLoc.longitude,
        unvisited[i].latitude,
        unvisited[i].longitude
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestIdx = i;
      }
    }

    const nextStop = unvisited.splice(nearestIdx, 1)[0];
    route.push({
      memberId: nextStop.memberId,
      type: 'pickup',
      latitude: nextStop.latitude,
      longitude: nextStop.longitude
    });
    currentLoc = nextStop;
  }

  // 2. Add final target destination
  route.push({
    type: 'destination',
    latitude: destination.latitude,
    longitude: destination.longitude
  });

  // 3. Back-calculate optimal pick-up arrival timing working backwards from Target Destination
  let currentTimestamp = targetArrivalTime;

  for (let i = route.length - 1; i > 0; i--) {
    const endPoint = route[i];
    const startPoint = route[i - 1];

    const distanceKm = calculateHaversineDistance(
      startPoint.latitude,
      startPoint.longitude,
      endPoint.latitude,
      endPoint.longitude
    );

    const travelTimeMs = (distanceKm / averageSpeedKph) * 60 * 60 * 1000;
    currentTimestamp = currentTimestamp - travelTimeMs;

    startPoint.estimatedTime = currentTimestamp;
  }

  route[route.length - 1].estimatedTime = targetArrivalTime;

  return route;
}

/**
 * Calculates straight line spherical distance between coordinates.
 */
function calculateHaversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}
```

---

## 4. Real-Time Tracking, Dynamic ETAs, and Alerts

While driving, the driver's client periodically sends coordinates, updates estimated remaining times, and automatically dispatches notifications for late pickups.

```typescript
/**
 * Executes inside GPS location stream updates on the Driver's phone.
 * If driver is running behind schedule (> 5 min), sends an org.carpool.alert warning.
 */
export async function processActiveGpsTick(
  currentLocation: { latitude: number; longitude: number },
  routeWaypoints: Waypoint[],
  scheduleId: string,
  eventTimestamp: number
): Promise<void> {

  // 1. Compute dynamic ETA changes for subsequent riders locally
  const nextWaypoints = recalculateWaypointsEta(currentLocation, routeWaypoints);

  // 2. Broadcast coordinates + precalculated ETA updates to Room
  await sendMatrixRoomMessage(scheduleId, 'org.carpool.location', {
    schedule_id: scheduleId,
    event_timestamp: eventTimestamp,
    latitude: currentLocation.latitude,
    longitude: currentLocation.longitude,
    eta_updates: nextWaypoints.map(wp => ({
      member_id: wp.memberId,
      type: wp.type,
      estimated_arrival: wp.estimatedTime
    }))
  });

  // 3. Monitor for delays
  for (const wp of nextWaypoints) {
    if (wp.type === 'pickup' && wp.originalScheduledTime && wp.estimatedTime) {
      const delayMinutes = (wp.estimatedTime - wp.originalScheduledTime) / (60 * 1000);

      // Dispatch room alert automatically if delay exceeds 5 minutes
      if (delayMinutes > 5) {
        await sendMatrixRoomMessage(scheduleId, 'org.carpool.alert', {
          schedule_id: scheduleId,
          event_timestamp: eventTimestamp,
          alert_type: 'delay',
          severity: 'warning',
          message: `Carpool is running approx ${Math.round(delayMinutes)} mins behind schedule!`
        });
      }
    }
  }
}
```
