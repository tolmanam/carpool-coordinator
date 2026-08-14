import * as TaskManager from 'expo-task-manager';
import * as BackgroundFetch from 'expo-background-fetch';
import { db } from '../db/client';
import { cachedSchedules, localIcalEvents } from '../db/schema';
import { eq } from 'drizzle-orm';
import {
  fetchMatrixRoomState,
  sendMatrixStateEvent,
  getSessionInfo,
  syncIcalFeed,
} from './matrixClient';

export const ICAL_SYNC_TASK = 'BACKGROUND_ICAL_SYNC_TASK';
const SYNC_INTERVAL_MS = 4 * 60 * 60 * 1000; // 4 hours

/**
 * Perform background synchronization for all schedules.
 * Implements the decentralized state-locking protocol via Matrix.
 */
export async function performBackgroundSync(): Promise<BackgroundFetch.BackgroundFetchResult> {
  try {
    const schedules = await db.select().from(cachedSchedules).all();
    if (schedules.length === 0) {
      return BackgroundFetch.BackgroundFetchResult.NoData;
    }

    const session = await getSessionInfo();
    const currentUserId = session.username
      ? (session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`)
      : '@anonymous:matrix.org';

    let updatedAny = false;

    for (const schedule of schedules) {
      // 1. Query the current Matrix State Event 'org.carpool.ical_lock'
      const currentLock = await fetchMatrixRoomState(schedule.scheduleId, 'org.carpool.ical_lock');
      const lastSync = currentLock?.content?.last_sync_timestamp || 0;

      // If synced recently by another client, skip to prevent API rate limits
      if (Date.now() - lastSync < SYNC_INTERVAL_MS) {
        continue;
      }

      // 2. Fetch Lock Attempt: Post updated lock with current client metadata
      await sendMatrixStateEvent(schedule.scheduleId, 'org.carpool.ical_lock', {
        last_sync_timestamp: Date.now(),
        synced_by: currentUserId,
        ical_feed_url: schedule.icalFeedUrl,
      });

      // 3. Sync the iCal feed locally
      // (This fetches the feed, parses occurrences, and updates SQLite)
      await syncIcalFeed(schedule.scheduleId);

      // 4. Query the parsed occurrences to upload them to the Matrix Room State
      const occurrences = await db
        .select()
        .from(localIcalEvents)
        .where(eq(localIcalEvents.scheduleId, schedule.scheduleId))
        .all();

      // 5. Push updated occurrences to Matrix room state 'org.carpool.schedules'
      await sendMatrixStateEvent(schedule.scheduleId, 'org.carpool.schedules', {
        title: schedule.title,
        ical_feed_url: schedule.icalFeedUrl,
        destination: {
          latitude: schedule.latitude,
          longitude: schedule.longitude,
          address_text: schedule.addressText,
        },
        parsed_events: occurrences, // Store occurrences list directly in State
      });

      // Release/Update Lock back to state
      await sendMatrixStateEvent(schedule.scheduleId, 'org.carpool.ical_lock', {
        last_sync_timestamp: Date.now(),
        synced_by: currentUserId,
        ical_feed_url: schedule.icalFeedUrl,
        status: 'released',
      });

      updatedAny = true;
    }

    return updatedAny
      ? BackgroundFetch.BackgroundFetchResult.NewData
      : BackgroundFetch.BackgroundFetchResult.NoData;
  } catch (error) {
    console.error('Background sync failure:', error);
    return BackgroundFetch.BackgroundFetchResult.Failed;
  }
}

// Define background task
TaskManager.defineTask(ICAL_SYNC_TASK, async () => {
  return await performBackgroundSync();
});

/**
 * Register background task with the OS
 */
export async function registerBackgroundSyncTask(): Promise<void> {
  try {
    const isRegistered = await TaskManager.isTaskRegisteredAsync(ICAL_SYNC_TASK);
    if (!isRegistered) {
      await BackgroundFetch.registerTaskAsync(ICAL_SYNC_TASK, {
        minimumInterval: 4 * 60 * 60, // 4 hours in seconds
        stopOnTerminate: false,
      });
    }
  } catch (err) {
    console.error('Failed to register background fetch task:', err);
  }
}
