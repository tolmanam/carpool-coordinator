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
import { Waypoint, recalculateWaypointsEta } from './routeOptimizer';

// Shared mock Matrix Room storage to simulate a shared federated Matrix cloud
export const mockMatrixCloud: {
  stateEvents: Record<string, Record<string, any>>; // roomId -> { eventType -> content }
  messages: Record<string, any[]>;                  // roomId -> list of messages
} = {
  stateEvents: {},
  messages: {},
};

export async function fetchMatrixRoomState(roomId: string, eventType: string): Promise<any> {
  const roomState = mockMatrixCloud.stateEvents[roomId] || {};
  return roomState[eventType] || null;
}

export async function sendMatrixStateEvent(roomId: string, eventType: string, content: any): Promise<void> {
  if (!mockMatrixCloud.stateEvents[roomId]) {
    mockMatrixCloud.stateEvents[roomId] = {};
  }
  mockMatrixCloud.stateEvents[roomId][eventType] = {
    type: eventType,
    state_key: roomId,
    content,
  };
}

export async function sendMatrixRoomMessage(roomId: string, eventType: string, content: any): Promise<void> {
  if (!mockMatrixCloud.messages[roomId]) {
    mockMatrixCloud.messages[roomId] = [];
  }
  mockMatrixCloud.messages[roomId].push({
    type: eventType,
    content,
    timestamp: Date.now(),
  });
}

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
      estimated_arrival: wp.estimatedTime,
    })),
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
          message: `Carpool is running approx ${Math.round(delayMinutes)} mins behind schedule!`,
        });
      }
    }
  }
}

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
 * Re-authenticates with new or updated Matrix credentials.
 * Wipes cached database tables to prevent cross-account data leaking, while preserving user settings.
 */
export async function reauthenticateAndClearCache(
  username: string,
  homeserver: string
): Promise<void> {
  // Preserve user preferences before wiping cache
  const notificationSound = await getNotificationSound();
  const themeMode = await getThemeMode();

  // Clear cached application state tables
  await db.delete(cachedSignups);
  await db.delete(cachedRoutes);
  await db.delete(localIcalEvents);
  await db.delete(cachedSchedules);
  await db.delete(cachedFamilyMembers);
  await db.delete(cachedFamilies);

  // Re-authenticate user
  await authenticateMatrix(username, homeserver);

  // Restore preserved user preferences
  if (notificationSound) await setNotificationSound(notificationSound);
  if (themeMode) await setThemeMode(themeMode);
}

/**
 * System Configuration: Notification Sound
 */
export async function setNotificationSound(sound: string): Promise<void> {
  await db
    .insert(localSettings)
    .values({ key: 'notification_sound', value: sound })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: sound } });
}

export async function getNotificationSound(): Promise<string> {
  try {
    const res = await db.select().from(localSettings).where(eq(localSettings.key, 'notification_sound')).get();
    return res?.value || 'default';
  } catch {
    return 'default';
  }
}

/**
 * System Configuration: Dark Mode Theme
 */
export async function setThemeMode(theme: 'light' | 'dark' | 'system'): Promise<void> {
  await db
    .insert(localSettings)
    .values({ key: 'theme_mode', value: theme })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: theme } });
}

export async function getThemeMode(): Promise<'light' | 'dark' | 'system'> {
  try {
    const res = await db.select().from(localSettings).where(eq(localSettings.key, 'theme_mode')).get();
    return (res?.value as 'light' | 'dark' | 'system') || 'system';
  } catch {
    return 'system';
  }
}

/**
 * Profile Configuration: Multi-Select User Profile Roles
 */
export async function updateUserProfileRoles(roles: string[]): Promise<void> {
  const session = await getSessionInfo();
  if (!session.username) return;

  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;
  const parentMemberId = `parent_${session.username}`;
  const rolesJson = JSON.stringify(roles);

  // Update in SQLite
  await db
    .insert(cachedFamilyMembers)
    .values({
      memberId: parentMemberId,
      matrixId: sanitizedUser,
      name: `${session.username.split(':')[0].replace('@', '') || 'User'}`,
      role: rolesJson,
    })
    .onConflictDoUpdate({
      target: cachedFamilyMembers.memberId,
      set: { role: rolesJson },
    });

  // Broadcast state event to Matrix room so roles are synchronized across the family group
  await sendMatrixStateEvent(sanitizedUser, 'org.carpool.family.profile', {
    matrix_id: sanitizedUser,
    roles,
    last_updated: Date.now(),
  });
}

export async function getUserProfileRoles(): Promise<string[]> {
  const session = await getSessionInfo();
  if (!session.username) return ['Parent', 'Driver'];

  const parentMemberId = `parent_${session.username}`;
  try {
    const res = await db.select().from(cachedFamilyMembers).where(eq(cachedFamilyMembers.memberId, parentMemberId)).get();
    if (!res?.role) return ['Parent', 'Driver'];
    if (res.role.startsWith('[')) {
      return JSON.parse(res.role);
    }
    return [res.role];
  } catch {
    return ['Parent', 'Driver'];
  }
}

export async function isUserParent(): Promise<boolean> {
  const roles = await getUserProfileRoles();
  return roles.some((r) => r.toLowerCase() === 'parent');
}

/**
 * Family Group Configuration: Manage Family Name & Members
 */
export async function updateFamilyName(familyName: string): Promise<void> {
  const session = await getSessionInfo();
  if (!session.username) return;

  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;

  await db
    .update(cachedFamilies)
    .set({ familyName, lastUpdated: new Date() })
    .where(eq(cachedFamilies.matrixId, sanitizedUser));

  // Broadcast to Matrix
  await sendMatrixStateEvent(sanitizedUser, 'org.carpool.family.profile', {
    matrix_id: sanitizedUser,
    family_name: familyName,
    last_updated: Date.now(),
  });
}

export async function addFamilyMember(name: string, roles: string[]): Promise<string> {
  const session = await getSessionInfo();
  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;
  const memberId = `mem_${Date.now()}_${Math.random().toString(36).substring(2, 6)}`;

  await db.insert(cachedFamilyMembers).values({
    memberId,
    matrixId: sanitizedUser,
    name,
    role: JSON.stringify(roles),
  });

  return memberId;
}

export async function removeFamilyMember(memberId: string): Promise<void> {
  await db.delete(cachedFamilyMembers).where(eq(cachedFamilyMembers.memberId, memberId));
}

/**
 * Carpool Group Configuration: Parent Role Creation, Owner Controls & Multiple Event Sources
 */
export async function createCarpoolGroup(name: string, eventSources: string[] = []): Promise<string> {
  const session = await getSessionInfo();
  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;

  // Permission check: Only Parents can create carpool groups
  const isParent = await isUserParent();
  if (!isParent) {
    throw new Error('Only users with the Parent role can create Carpool Groups.');
  }

  const scheduleId = `sched_${Date.now()}`;
  const primaryFeed = eventSources[0] || '';

  await db.insert(cachedSchedules).values({
    scheduleId,
    title: name,
    icalFeedUrl: primaryFeed,
    eventSourcesJson: JSON.stringify(eventSources),
    ownerId: sanitizedUser,
    participantsJson: JSON.stringify([sanitizedUser]),
    latitude: 34.0415,
    longitude: -118.4520,
    addressText: 'Carpool Group Location',
  });

  // Activate E2EE
  await activateRoomE2EE(scheduleId);

  // Broadcast group state event
  await sendMatrixStateEvent(scheduleId, 'org.carpool.schedule', {
    schedule_id: scheduleId,
    title: name,
    owner_id: sanitizedUser,
    event_sources: eventSources,
    participants: [sanitizedUser],
  });

  return scheduleId;
}

export async function updateGroupEventSources(
  scheduleId: string,
  eventSources: string[]
): Promise<void> {
  const session = await getSessionInfo();
  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;

  const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
  if (!schedule) throw new Error('Carpool group not found.');

  // Permission check: Only group owner can edit event sources
  if (schedule.ownerId && schedule.ownerId !== sanitizedUser) {
    throw new Error('Only the group owner/manager can edit event sources.');
  }

  const primaryFeed = eventSources[0] || '';

  await db
    .update(cachedSchedules)
    .set({
      icalFeedUrl: primaryFeed,
      eventSourcesJson: JSON.stringify(eventSources),
    })
    .where(eq(cachedSchedules.scheduleId, scheduleId));

  // Sync events from all sources
  await syncMultipleIcalFeeds(scheduleId);
}

export async function addParticipantFamily(scheduleId: string, familyMatrixId: string): Promise<void> {
  const cleanId = familyMatrixId.startsWith('@') ? familyMatrixId : `@${familyMatrixId}:matrix.org`;
  const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
  if (!schedule) return;

  let currentParticipants: string[] = [];
  if (schedule.participantsJson) {
    try { currentParticipants = JSON.parse(schedule.participantsJson); } catch {}
  }

  if (!currentParticipants.includes(cleanId)) {
    currentParticipants.push(cleanId);
    await db
      .update(cachedSchedules)
      .set({ participantsJson: JSON.stringify(currentParticipants) })
      .where(eq(cachedSchedules.scheduleId, scheduleId));
  }

  await inviteMember(scheduleId, cleanId);
}

export async function removeParticipantFamily(scheduleId: string, familyMatrixId: string): Promise<void> {
  const session = await getSessionInfo();
  const sanitizedUser = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;
  const cleanId = familyMatrixId.startsWith('@') ? familyMatrixId : `@${familyMatrixId}:matrix.org`;

  const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
  if (!schedule) return;

  // Non-owner can remove themselves, owner can remove anyone
  const isOwner = schedule.ownerId === sanitizedUser;
  const isSelf = cleanId === sanitizedUser;

  if (!isOwner && !isSelf) {
    throw new Error('Only group owners or the family itself can remove a participant from a Carpool Group.');
  }

  let currentParticipants: string[] = [];
  if (schedule.participantsJson) {
    try { currentParticipants = JSON.parse(schedule.participantsJson); } catch {}
  }

  const updatedParticipants = currentParticipants.filter((id) => id !== cleanId);

  await db
    .update(cachedSchedules)
    .set({ participantsJson: JSON.stringify(updatedParticipants) })
    .where(eq(cachedSchedules.scheduleId, scheduleId));
}

export async function syncMultipleIcalFeeds(scheduleId: string): Promise<void> {
  const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
  if (!schedule) return;

  let sources: string[] = [];
  if (schedule.eventSourcesJson) {
    try { sources = JSON.parse(schedule.eventSourcesJson); } catch {}
  }

  if (sources.length === 0 && schedule.icalFeedUrl) {
    sources = [schedule.icalFeedUrl];
  }

  if (sources.length === 0) {
    await syncIcalFeed(scheduleId);
    return;
  }

  for (const url of sources) {
    if (url) {
      await db.update(cachedSchedules).set({ icalFeedUrl: url }).where(eq(cachedSchedules.scheduleId, scheduleId));
      await syncIcalFeed(scheduleId);
    }
  }
}

// Shared E2EE Key storage to simulate Olm/Megolm secure keys in local device memory
export const mockE2eeRoomKeys: Record<string, string> = {};

/**
 * Activates Olm/Megolm E2EE for a specific room (circle)
 */
export async function activateRoomE2EE(roomId: string): Promise<void> {
  // Generate high-entropy room key (Megolm session key)
  const megolmKey = 'megolm_session_' + Math.random().toString(36).substring(2, 15);
  mockE2eeRoomKeys[roomId] = megolmKey;

  // Send state event to room activating encryption
  await sendMatrixStateEvent(roomId, 'm.room.encryption', {
    algorithm: 'm.megolm.v1.aes-sha2',
    rotation_period_ms: 604800000,
  });
}

/**
 * Checks if E2EE is active for a room
 */
export async function isRoomE2eeActive(roomId: string): Promise<boolean> {
  const encryptionState = await fetchMatrixRoomState(roomId, 'm.room.encryption');
  return encryptionState !== null;
}

/**
 * Simulated encryption helper: wraps a standard JSON message payload into an encrypted ciphertext envelope
 */
export function encryptPayloadE2EE(roomId: string, payload: any): any {
  const key = mockE2eeRoomKeys[roomId];
  if (!key) {
    // If E2EE is not activated or key is missing, return unencrypted
    return payload;
  }

  // Simulated ciphertext envelope (resembling Megolm JSON payload)
  return {
    algorithm: 'm.megolm.v1.aes-sha2',
    sender_key: 'sender_key_' + roomId,
    ciphertext: Buffer.from(JSON.stringify(payload)).toString('base64'), // Base64 encoded payload to simulate ciphertext
    session_id: key,
  };
}

/**
 * Simulated decryption helper: unwraps an encrypted ciphertext envelope back to original JSON payload
 */
export function decryptPayloadE2EE(roomId: string, encryptedPayload: any): any {
  if (encryptedPayload?.algorithm === 'm.megolm.v1.aes-sha2' && encryptedPayload?.ciphertext) {
    try {
      const decodedStr = Buffer.from(encryptedPayload.ciphertext, 'base64').toString('utf-8');
      return JSON.parse(decodedStr);
    } catch {
      return encryptedPayload;
    }
  }
  return encryptedPayload;
}

/**
 * Simulated/Mock OIDC/SSO federated Matrix authentication flow.
 * Redirects visually (conceptually), retrieves secure token, and completes login.
 */
export async function authenticateMatrixSSO(homeserver: string): Promise<void> {
  const mockSsoUsername = 'sso_alice';
  await authenticateMatrix(mockSsoUsername, homeserver);

  // Set extra setting for SSO token
  await db
    .insert(localSettings)
    .values({ key: 'sso_token', value: 'sso_tok_' + Math.random().toString(36).substring(2, 10) })
    .onConflictDoUpdate({ target: localSettings.key, set: { value: 'true' } });
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

  // Automatically activate Olm/Megolm E2EE for this circle
  await activateRoomE2EE(scheduleId);

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
