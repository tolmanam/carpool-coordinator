# Matrix Events & Client SQLite Schemas - Carpool Coordinator

This document specifies the exact JSON schemas for custom Matrix events and the corresponding Drizzle ORM schemas for the local-first SQLite database.

---

## 1. Custom Matrix Events (Namespace: `org.carpool`)

All custom events are stored inside the private, encrypted Matrix room representing the coordination group.

### 1.1. `org.carpool.family.profile` (State Event)
Defines a household's profile. Sent with the state key as the Matrix User ID of the family administrator.

```json
{
  "type": "org.carpool.family.profile",
  "state_key": "@alice:matrix.org",
  "content": {
    "family_name": "The Connor Family",
    "home_location": {
      "latitude": 34.0194,
      "longitude": -118.4912,
      "address_text": "734 Ocean Avenue, Santa Monica, CA"
    },
    "members": [
      {
        "id": "member_connor_1",
        "name": "John Connor",
        "role": "child",
        "is_adult": false,
        "can_drive": false,
        "email": "john@example.com",
        "phone": "555-0199",
        "avatar_url": "",
        "emergency_contact": "Sarah Connor (555-0100)",
        "matrix_id": ""
      },
      {
        "id": "member_connor_2",
        "name": "Sarah Connor",
        "role": "parent",
        "is_adult": true,
        "can_drive": true,
        "email": "sarah@example.com",
        "phone": "555-0100",
        "avatar_url": "",
        "emergency_contact": "Kyle Reese (555-0101)",
        "matrix_id": "@sarah:matrix.org"
      }
    ]
  }
}

### 1.1b. `org.carpool.organization` (Space / State Event)
Defines an Organization space containing shared schedules and child Carpool Circle rooms.

```json
{
  "type": "org.carpool.organization",
  "state_key": "",
  "content": {
    "org_id": "org_westside_soccer",
    "name": "Westside Soccer Club",
    "ical_feed_url": "https://sports-club.org/calendars/u10.ics",
    "is_carpool_org": true
  }
}
```

### 1.2. `org.carpool.schedules` (State Event)
Defines a shared target destination and associated recurrent iCal URL. Sent with a unique schedule ID as the state key.

```json
{
  "type": "org.carpool.schedules",
  "state_key": "sched_soccer_2023",
  "content": {
    "title": "Westside Soccer Practice",
    "ical_feed_url": "https://sports-club.org/calendars/u10.ics",
    "destination": {
      "latitude": 34.0415,
      "longitude": -118.4520,
      "address_text": "Clover Park Field 2"
    }
  }
}
```

### 1.3. `org.carpool.ical_lock` (State Event)
Coordinates background task syncing to prevent multiple clients from fetching the same external iCal URL concurrently. Sent with the schedule ID as the state key.

```json
{
  "type": "org.carpool.ical_lock",
  "state_key": "sched_soccer_2023",
  "content": {
    "last_sync_timestamp": 1698391800000,
    "synced_by": "@alice:matrix.org",
    "ical_feed_url": "https://sports-club.org/calendars/u10.ics"
  }
}
```

### 1.4. `org.carpool.signup` (Message Event)
Sent by a parent to sign up their family members as riders or themselves as drivers for a specific calendar instance.

```json
{
  "type": "org.carpool.signup",
  "content": {
    "schedule_id": "sched_soccer_2023",
    "event_timestamp": 1698393600000,
    "member_id": "member_connor_1",
    "role": "rider",
    "status": "scheduled"
  }
}
```

### 1.5. `org.carpool.route` (Message Event)
Calculated and published by the assigned Driver's client. Outlines the optimal pick-up sequences and planned ETAs.

```json
{
  "type": "org.carpool.route",
  "content": {
    "schedule_id": "sched_soccer_2023",
    "event_timestamp": 1698393600000,
    "driver_id": "member_connor_2",
    "estimated_departure": 1698391800000,
    "waypoints": [
      {
        "member_id": "member_connor_2",
        "type": "driver_start",
        "estimated_time": 1698391800000
      },
      {
        "member_id": "member_smith_1",
        "type": "pickup",
        "estimated_time": 1698392400000
      },
      {
        "type": "destination",
        "estimated_time": 1698393600000
      }
    ],
    "route_polyline": "u{~vH{g_u@gA_@gB..."
  }
}
```

### 1.6. `org.carpool.location` (Message Event)
High-frequency ephemeral coordinate streaming. Contains real-time GPS locations and dynamic calculated ETAs to subsequent stops.

```json
{
  "type": "org.carpool.location",
  "content": {
    "schedule_id": "sched_soccer_2023",
    "event_timestamp": 1698393600000,
    "driver_id": "member_connor_2",
    "latitude": 34.0210,
    "longitude": -118.4800,
    "heading": 180.5,
    "speed": 11.2,
    "eta_updates": [
      {
        "member_id": "member_smith_1",
        "estimated_arrival": 1698392405000
      },
      {
        "type": "destination",
        "estimated_arrival": 1698393610000
      }
    ]
  }
}
```

---

## 2. Client-Side SQLite Database Schema (Drizzle ORM)

Below is the definitive schema for the local-first client-side SQLite database utilizing `expo-sqlite` and `drizzle-orm/sqlite-core`.

```typescript
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
  id: text('id').primaryKey(), // Concatenation of scheduleId + timestamp + memberId
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
  id: text('id').primaryKey(), // Concatenation of scheduleId + timestamp
  scheduleId: text('schedule_id').notNull(),
  eventTimestamp: integer('event_timestamp').notNull(),
  driverId: text('driver_id').notNull(),
  estimatedDeparture: integer('estimated_departure').notNull(),
  waypointsJson: text('waypoints_json').notNull(), // Serialized waypoint sequence array
  routePolyline: text('route_polyline'),           // Encoded route polyline
}, (table) => ({
  pk: primaryKey({ columns: [table.scheduleId, table.eventTimestamp] }),
}));
```

### Schema Synchronisation Flow

1. On App Launch, standard migrations run natively using:
   ```typescript
   import { migrate } from 'drizzle-orm/expo-sqlite/migrator';
   ```
2. When the Matrix sync engine receives a new state or message event, the client parses the event payload and inserts/upserts the matching record inside the local SQLite database.
3. The UI queries the SQLite tables reactively using Drizzle query listeners or state hooks, ensuring instant, lag-free rendering of offline schedules.
