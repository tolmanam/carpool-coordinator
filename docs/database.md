# Matrix Event Schemas & Client Storage - Carpool Coordinator

This document details the decentralization of data schemas. Since we do not use a centralized database, all storage is split between **Matrix Room Custom State & Message Events** (for cross-client shared coordination state) and a **Client-Side SQLite Database** (for private/offline local-first indexing).

---

## 1. Custom Matrix Events

Matrix supports custom extensible JSON events. The namespace `org.carpool` is used for all custom event types.

### 1.1. `org.carpool.family.profile` (State Event)

Defines a household profile. Sent as a **State Event** with the state key as the Matrix ID of the family administrator.

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
        "role": "child"
      },
      {
        "id": "member_connor_2",
        "name": "Sarah Connor",
        "role": "parent"
      }
    ]
  }
}
```

### 1.2. `org.carpool.schedules` (State Event)

Published to configure the shared destinations and recurrent iCal links. Sent as a **State Event** with a unique schedule ID as the state key.

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

### 1.3. `org.carpool.signup` (Message Event)

Sent by a parent client to sign up their child as a rider or themselves as a driver for a specific calendar instance.

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

### 1.4. `org.carpool.route` (Message Event)

Calculated and published by the assigned Driver's client. It calculates the optimal route order and estimated pick-up times for all riders.

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

---

## 2. Client-Side SQLite Database Schema

Each client retains a local cache of the synchronized room events and private local data (e.g., raw calendar feeds they shouldn't publish directly, route options). Below is the recommended SQLite schema.

### Table: `local_settings`

| Column | Type | Constraints | Description |
|---|---|---|---|
| **key** | TEXT | PRIMARY KEY | Setting namespace. |
| **value** | TEXT | NOT NULL | Serialized setting value. |

### Table: `cached_families`

| Column | Type | Constraints | Description |
|---|---|---|---|
| **matrix_id** | TEXT | PRIMARY KEY | Matrix ID of the family admin user. |
| **family_name** | TEXT | NOT NULL | Family display name. |
| **latitude** | REAL | NOT NULL | Home Latitude. |
| **longitude** | REAL | NOT NULL | Home Longitude. |
| **address_text** | TEXT | | Human-readable address. |

### Table: `cached_family_members`

| Column | Type | Constraints | Description |
|---|---|---|---|
| **member_id** | TEXT | PRIMARY KEY | Unique member ID within family. |
| **matrix_id** | TEXT | REFERENCES `cached_families(matrix_id)` | Owner family. |
| **name** | TEXT | NOT NULL | Member display name. |
| **role** | TEXT | NOT NULL | Role (parent, child, etc). |

### Table: `local_ical_events`

Stores events fetched and parsed locally by the client before route mapping is completed.

| Column | Type | Constraints | Description |
|---|---|---|---|
| **id** | TEXT | PRIMARY KEY | Event UID from `.ics`. |
| **schedule_id** | TEXT | NOT NULL | References schedule configuration. |
| **title** | TEXT | NOT NULL | Event title. |
| **start_time** | INTEGER | NOT NULL | Unix timestamp of start time. |
| **end_time** | INTEGER | NOT NULL | Unix timestamp of end time. |
