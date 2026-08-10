import { sqliteTable, text, real, integer, primaryKey } from 'drizzle-orm/sqlite-core';

// Local key-value settings store
export const localSettings = sqliteTable('local_settings', {
  key: text('key').primaryKey(),
  value: text('value').notNull(),
});

// Cached family profiles fetched from org.carpool.family.profile state events
export const cachedFamilies = sqliteTable('cached_families', {
  matrixId: text('matrix_id').primaryKey(), // Owner matrix username
  familyName: text('family_name').notNull(),
  latitude: real('latitude').notNull(),
  longitude: real('longitude').notNull(),
  addressText: text('address_text'),
  lastUpdated: integer('last_updated', { mode: 'timestamp' }).notNull(),
});

// Individual cached family members
export const cachedFamilyMembers = sqliteTable('cached_family_members', {
  memberId: text('member_id').primaryKey(), // Generated member unique identifier
  matrixId: text('matrix_id')
    .notNull()
    .references(() => cachedFamilies.matrixId, { onDelete: 'cascade' }),
  name: text('name').notNull(),
  role: text('role').notNull(), // 'parent' | 'child'
});

// Local cached copy of configured schedules/destinations (from state events)
export const cachedSchedules = sqliteTable('cached_schedules', {
  scheduleId: text('schedule_id').primaryKey(),
  title: text('title').notNull(),
  icalFeedUrl: text('ical_feed_url'),
  latitude: real('latitude').notNull(),
  longitude: real('longitude').notNull(),
  addressText: text('address_text'),
});

// Parsed calendar instances extracted from the fetched iCal feeds
export const localIcalEvents = sqliteTable('local_ical_events', {
  id: text('id').primaryKey(), // Unique UID from iCal .ics
  scheduleId: text('schedule_id')
    .notNull()
    .references(() => cachedSchedules.scheduleId, { onDelete: 'cascade' }),
  title: text('title').notNull(),
  startTime: integer('start_time').notNull(), // Unix timestamp (ms)
  endTime: integer('end_time').notNull(),     // Unix timestamp (ms)
});

// Sign-ups synchronized from org.carpool.signup room messages
export const cachedSignups = sqliteTable('cached_signups', {
  id: text('id').notNull(), // Concatenation of scheduleId + timestamp + memberId
  scheduleId: text('schedule_id').notNull(),
  eventTimestamp: integer('event_timestamp').notNull(), // Matching iCal occurrence
  memberId: text('member_id').notNull(),
  role: text('role').notNull(),     // 'rider' | 'driver'
  status: text('status').notNull(), // 'scheduled' | 'canceled' | 'sick'
}, (table) => ({
  pk: primaryKey({ columns: [table.scheduleId, table.eventTimestamp, table.memberId] }),
}));

// Route structures synchronized from org.carpool.route messages
export const cachedRoutes = sqliteTable('cached_routes', {
  id: text('id').notNull(), // Concatenation of scheduleId + timestamp
  scheduleId: text('schedule_id').notNull(),
  eventTimestamp: integer('event_timestamp').notNull(),
  driverId: text('driver_id').notNull(),
  estimatedDeparture: integer('estimated_departure').notNull(),
  waypointsJson: text('waypoints_json').notNull(), // Serialized waypoint sequence array
  routePolyline: text('route_polyline'),           // Encoded route polyline
}, (table) => ({
  pk: primaryKey({ columns: [table.scheduleId, table.eventTimestamp] }),
}));
