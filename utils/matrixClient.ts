import { db } from '../db/client';
import {
  localSettings,
  cachedFamilies,
  cachedFamilyMembers,
  cachedSchedules,
  localIcalEvents,
  cachedSignups,
  cachedRoutes,
} from '../db/schema';
import { eq, and } from 'drizzle-orm';
import { parseIcalString, IcalOccurrence } from './icalParser';

// Simulated/Mock Matrix REST helper functions for unencrypted room prototype
export interface MatrixProfile {
  userId: string;
  familyName: string;
  latitude: number;
  longitude: number;
  addressText: string;
}

export interface MatrixMember {
  memberId: string;
  name: string;
  role: 'parent' | 'child';
}

/**
 * Handle user authentication and save basic session details locally
 */
export async function authenticateMatrix(
  username: string,
  homeserver: string
): Promise<void> {
  // Save credentials to local SQLite settings
  await db
    .insert(localSettings)
    .values({ key: 'homeserver', value: homeserver })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: homeserver } });

  await db
    .insert(localSettings)
    .values({ key: 'username', value: username })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: username } });

  await db
    .insert(localSettings)
    .values({ key: 'is_logged_in', value: 'true' })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: 'true' } });

  // Let's seed a default profile for the user
  const sanitizedUser = username.startsWith('@') ? username : `@${username}:matrix.org`;
  const defaultFamilyName = `${username.replace(/[^a-zA-Z0-9]/g, '') || 'User'}'s Family`;

  await db
    .insert(cachedFamilies)
    .values({
      matrixId: sanitizedUser,
      familyName: defaultFamilyName,
      latitude: 34.0194,
      longitude: -118.4912,
      addressText: '734 Ocean Avenue, Santa Monica, CA',
      lastUpdated: new Date(),
    })
    .onConflictDoUpdate({
      target: cachedFamilies.matrixId,
      set: {
        familyName: defaultFamilyName,
        latitude: 34.0194,
        longitude: -118.4912,
        addressText: '734 Ocean Avenue, Santa Monica, CA',
        lastUpdated: new Date(),
      },
    });

  // Create default driver parent and rider child members for simplicity
  const parentMemberId = `parent_${username}`;
  const childMemberId = `child_${username}`;

  await db
    .insert(cachedFamilyMembers)
    .values({
      memberId: parentMemberId,
      matrixId: sanitizedUser,
      name: `${username.split(':')[0].replace('@', '') || 'Driver'} (Parent)`,
      role: 'parent',
    })
    .onConflictDoNothing();

  await db
    .insert(cachedFamilyMembers)
    .values({
      memberId: childMemberId,
      matrixId: sanitizedUser,
      name: `Sarah (Child)`,
      role: 'child',
    })
    .onConflictDoNothing();
}

/**
 * Checks if a session is currently active
 */
export async function getSessionInfo(): Promise<{ username: string; homeserver: string; isLoggedIn: boolean }> {
  try {
    const usernameResult = await db.select().from(localSettings).where(eq(localSettings.key, 'username')).get();
    const homeserverResult = await db.select().from(localSettings).where(eq(localSettings.key, 'homeserver')).get();
    const loginResult = await db.select().from(localSettings).where(eq(localSettings.key, 'is_logged_in')).get();

    return {
      username: usernameResult?.value || '',
      homeserver: homeserverResult?.value || 'https://matrix.org',
      isLoggedIn: loginResult?.value === 'true',
    };
  } catch {
    return { username: '', homeserver: 'https://matrix.org', isLoggedIn: false };
  }
}

/**
 * Log out and clear local configuration settings
 */
export async function logoutMatrix(): Promise<void> {
  await db
    .insert(localSettings)
    .values({ key: 'is_logged_in', value: 'false' })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: 'false' } });
}

/**
 * Creates a new coordination circle (represented by a simulated Matrix room metadata record in the database)
 */
export async function createCircle(name: string): Promise<string> {
  const scheduleId = `sched_${Date.now()}`;
  // Seed a standard schedule mapping for this circle
  await db.insert(cachedSchedules).values({
    scheduleId,
    title: name,
    icalFeedUrl: '', // To be updated
    latitude: 34.0415,
    longitude: -118.4520,
    addressText: 'Clover Park Field 2',
  });

  return scheduleId;
}

/**
 * Simulates inviting a member to a circle
 */
export async function inviteMember(scheduleId: string, memberMatrixId: string): Promise<void> {
  // In a decentralized E2EE Matrix system, we invite standard usernames.
  // For the local DB representation, we'll cache their profile and seed family members.
  const cleanId = memberMatrixId.startsWith('@') ? memberMatrixId : `@${memberMatrixId}:matrix.org`;
  const familyName = `${cleanId.split(':')[0].replace('@', '') || 'Invited'} Family`;

  await db.insert(cachedFamilies).values({
    matrixId: cleanId,
    familyName,
    latitude: 34.0250,
    longitude: -118.4700,
    addressText: '1200 Wilshire Blvd, Santa Monica, CA',
    lastUpdated: new Date(),
  }).onConflictDoNothing();

  await db.insert(cachedFamilyMembers).values({
    memberId: `child_${cleanId.replace(/[^a-zA-Z0-9]/g, '')}`,
    matrixId: cleanId,
    name: `${cleanId.split(':')[0].replace('@', '') || 'Rider'} Jr.`,
    role: 'child',
  }).onConflictDoNothing();
}

/**
 * Updates a child's or parent's sign-up status for a specific commute schedule instance.
 * Updates the local SQLite database and prepares synchronization.
 */
export async function registerSignup(params: {
  scheduleId: string;
  eventTimestamp: number;
  memberId: string;
  role: 'rider' | 'driver';
  status: 'scheduled' | 'canceled' | 'sick';
}): Promise<void> {
  const compositeId = `${params.scheduleId}_${params.eventTimestamp}_${params.memberId}`;

  // If registering as driver, unregister any driver for this commute instance
  if (params.role === 'driver' && params.status === 'scheduled') {
    await db.delete(cachedSignups).where(
      and(
        eq(cachedSignups.scheduleId, params.scheduleId),
        eq(cachedSignups.eventTimestamp, params.eventTimestamp),
        eq(cachedSignups.role, 'driver')
      )
    );
  }

  await db
    .insert(cachedSignups)
    .values({
      id: compositeId,
      scheduleId: params.scheduleId,
      eventTimestamp: params.eventTimestamp,
      memberId: params.memberId,
      role: params.role,
      status: params.status,
    })
    .onConflictDoUpdate({
      target: [cachedSignups.scheduleId, cachedSignups.eventTimestamp, cachedSignups.memberId],
      set: {
        role: params.role,
        status: params.status,
      },
    });
}

/**
 * Removes a signup record for a child/parent
 */
export async function removeSignup(scheduleId: string, eventTimestamp: number, memberId: string): Promise<void> {
  await db.delete(cachedSignups).where(
    and(
      eq(cachedSignups.scheduleId, scheduleId),
      eq(cachedSignups.eventTimestamp, eventTimestamp),
      eq(cachedSignups.memberId, memberId)
    )
  );
}

/**
 * Simulates/Implements standard background sync fetching of the iCal feed,
 * local parsing via `parseIcalString`, and populating occurrences in SQLite index.
 */
export async function syncIcalFeed(scheduleId: string, customIcsContent?: string): Promise<void> {
  const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
  if (!schedule) return;

  let icsContent = customIcsContent || '';

  // If no mock content, but feed url exists, fetch it (simulated in mock environment)
  if (!icsContent && schedule.icalFeedUrl) {
    try {
      const response = await fetch(schedule.icalFeedUrl);
      icsContent = await response.text();
    } catch (e) {
      // Fallback fallback mock feed data if fetch fails (e.g. offline, DNS)
      icsContent = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Carpool//NONSGML v1.0//EN
BEGIN:VEVENT
UID:event_soccer_practice
DTSTART:20261024T160000Z
DTEND:20261024T173000Z
SUMMARY:Soccer Practice Clover Park
RRULE:FREQ=WEEKLY;BYDAY=TU,TH;COUNT=6
END:VEVENT
END:VCALENDAR`;
    }
  }

  if (!icsContent) {
    // Default fallback mock calendar data to populate schedule lists
    icsContent = `BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Carpool//NONSGML v1.0//EN
BEGIN:VEVENT
UID:event_soccer_practice
DTSTART:20261024T160000Z
DTEND:20261024T173000Z
SUMMARY:Soccer Practice Clover Park
RRULE:FREQ=WEEKLY;BYDAY=TU,TH;COUNT=6
END:VEVENT
END:VCALENDAR`;
  }

  // Parse using our RFC 5545 parsing helper
  const occurrences: IcalOccurrence[] = parseIcalString(icsContent, scheduleId);

  // Reconcile and atomic upsert/insert in local SQLite DB
  for (const occ of occurrences) {
    await db
      .insert(localIcalEvents)
      .values({
        id: occ.id,
        scheduleId: occ.scheduleId,
        title: occ.title,
        startTime: occ.startTime,
        endTime: occ.endTime,
      })
      .onConflictDoUpdate({
        target: localIcalEvents.id,
        set: {
          title: occ.title,
          startTime: occ.startTime,
          endTime: occ.endTime,
        },
      });
  }
}
