# Matrix Events & Client SQLite Schemas - Carpool Coordinator

This document specifies the exact JSON schemas for custom Matrix events and the corresponding SQLite database schemas implemented in Flutter via `DatabaseService` (`lib/services/database_service.dart`).

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
```

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
    "status": "scheduled",
    "seat_capacity": 4
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

## 2. Client-Side SQLite Database Schema (Flutter `sqflite`)

The local offline database is managed in Flutter via `DatabaseService` (`lib/services/database_service.dart`) using `sqflite` (mobile), `sqflite_common_ffi` (desktop/tests), or `sqflite_common_ffi_web` (web).

### Core Tables SQL Schema

```sql
-- App settings and Matrix credentials cache
CREATE TABLE settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

-- Family profiles
CREATE TABLE family_profiles (
  family_id TEXT PRIMARY KEY,
  family_name TEXT NOT NULL,
  address_text TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL
);

-- Family members
CREATE TABLE family_members (
  member_id TEXT PRIMARY KEY,
  family_id TEXT NOT NULL,
  member_name TEXT NOT NULL,
  role TEXT NOT NULL,
  is_adult INTEGER NOT NULL DEFAULT 1,
  can_drive INTEGER NOT NULL DEFAULT 0,
  member_matrix_id TEXT DEFAULT '',
  email TEXT DEFAULT '',
  phone TEXT DEFAULT '',
  avatar_url TEXT DEFAULT '',
  emergency_contact TEXT DEFAULT '',
  FOREIGN KEY (family_id) REFERENCES family_profiles (family_id) ON DELETE CASCADE
);

-- Organizations (Matrix Spaces)
CREATE TABLE organizations (
  org_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  ical_feed_url TEXT NOT NULL,
  is_carpool_org INTEGER NOT NULL DEFAULT 1
);

-- Carpool Circles (Child Rooms)
CREATE TABLE carpool_circles (
  circle_id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  name TEXT NOT NULL,
  room_id TEXT NOT NULL,
  FOREIGN KEY (org_id) REFERENCES organizations (org_id) ON DELETE CASCADE
);

-- Organization Participants
CREATE TABLE organization_participants (
  id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  member_id TEXT NOT NULL,
  circle_id TEXT DEFAULT '',
  FOREIGN KEY (org_id) REFERENCES organizations (org_id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members (member_id) ON DELETE CASCADE
);

-- Chat Messages
CREATE TABLE chat_messages (
  message_id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  content TEXT NOT NULL,
  timestamp INTEGER NOT NULL
);

-- Schedules
CREATE TABLE schedules (
  schedule_id TEXT PRIMARY KEY,
  org_id TEXT NOT NULL,
  title TEXT NOT NULL,
  ical_feed_url TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  address_text TEXT NOT NULL,
  FOREIGN KEY (org_id) REFERENCES organizations (org_id) ON DELETE CASCADE
);

-- Local iCal parsed events
CREATE TABLE local_ical_events (
  id TEXT PRIMARY KEY,
  schedule_id TEXT NOT NULL,
  title TEXT NOT NULL,
  start_time INTEGER NOT NULL,
  end_time INTEGER NOT NULL,
  FOREIGN KEY (schedule_id) REFERENCES schedules (schedule_id) ON DELETE CASCADE
);

-- Signups (Ride / Driver)
CREATE TABLE signups (
  id TEXT PRIMARY KEY,
  schedule_id TEXT NOT NULL,
  event_timestamp INTEGER NOT NULL,
  member_id TEXT NOT NULL,
  role TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'scheduled',
  seat_capacity INTEGER DEFAULT 4,
  FOREIGN KEY (schedule_id) REFERENCES schedules (schedule_id) ON DELETE CASCADE,
  FOREIGN KEY (member_id) REFERENCES family_members (member_id) ON DELETE CASCADE
);

-- Pending offline Matrix events queue
CREATE TABLE pending_offline_events (
  id TEXT PRIMARY KEY,
  event_type TEXT NOT NULL,
  room_id TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  created_at INTEGER NOT NULL
);

-- Route Waypoints
CREATE TABLE route_waypoints (
  id TEXT PRIMARY KEY,
  schedule_id TEXT NOT NULL,
  event_timestamp INTEGER NOT NULL,
  member_id TEXT NOT NULL,
  type TEXT NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  estimated_time INTEGER NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (schedule_id) REFERENCES schedules (schedule_id) ON DELETE CASCADE
);
```

### Schema Synchronization Flow

1. On App Launch, `DatabaseService.init()` initializes SQLite database tables across supported platforms.
2. Incoming Matrix state and message events from `/sync` are parsed by `MatrixService` and updated in SQLite via `DatabaseService`.
3. Flutter UI components observe state via Provider (`ChangeNotifierProvider`), ensuring reactive UI rendering.
