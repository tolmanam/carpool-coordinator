# Technical Architecture & Design - Carpool Coordinator

This document defines the core architecture, decentralized philosophy, and platform constraints of the **Carpool Coordinator** application.

---

## 1. Decentralization Philosophy: Why Matrix?

To achieve **zero cloud hosting or database maintenance costs** and absolute privacy for families, we eliminate central application servers. Instead, we use **Matrix** (the open standard for secure, decentralized, real-time communication) as our virtual backend.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        Mobile Client (Flutter)                         │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │   IcalParserService     │            │ RouteOptimizerService   │   │
│   │   (Background Sync &    │            │ (In-app Heuristic TSP + │   │
│   │   State Coordination)   │            │   Dynamic ETA Engine)   │   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │     DatabaseService     │            │      MatrixService      │   │
│   │    (Local SQLite with   │            │ (Sync / Send Room State │   │
│   │    sqflite / FFI)       │            │   & Message Events)     │   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Matrix Client-Server HTTP API v3
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Decentralized Federated                         │
│                           Matrix Homeservers                           │
│                     (matrix.org, self-hosted, etc.)                    │
└────────────────────────────────────────────────────────────────────────┘
```

### Direct Mapping of Concepts

* **Identity & Authentication**: Users authenticate with any Matrix homeserver using their standard Matrix ID (`@user:server.org`) and credentials or federated SSO/OIDC. At least one adult per family has a Matrix ID to log in and participate on behalf of the family. (See [Matrix Connection Specification](MATRIX_CONNECTION.md) for homeserver auto-discovery, authentication, and sync resilience protocols).
* **Family Group**: Modeled as a private Matrix Room containing household members (adults, children, drivers) and individual profile details (email, phone, avatar, emergency contact, booster seat flags, medical notes).
* **Organization**: Represented as a Matrix Space (`m.space`) tagged with `org.carpool.organization: true` or designated Carpool Coordinator space metadata properties. Organizations manage shared schedules (iCal feeds).
* **Carpool Circle**: Represented as child Matrix Rooms (`m.space.child`) under an Organization Space. Families in an Organization subdivide into overlapping circles to manage specific pickup/dropoff responsibilities.
* **State Sync**: Shared group profiles (member details, home coordinates) and destination configurations are stored directly in Matrix rooms as standard **Matrix State Events** (`m.room.state`).
* **Group Messaging / Chat**: Basic group chat is enabled inside Family rooms, Organization spaces/rooms, and Carpool Circle rooms using `m.room.message`. Direct 1-on-1 messaging between individuals across families is prevented within the app interface.
* **Schedules & Sign-ups**: Shifts, attendance sign-ups, vehicle seat capacity limits, and equipment requirements are shared as custom Matrix Message Events (`org.carpool.signup`).
* **Real-Time Coordinates & ETAs**: Streamed during active carpools as ephemeral, high-frequency room messages (`org.carpool.location`).

---

## 2. Shift to Client-Side Processing

All heavy computational tasks are distributed to individual user devices, eliminating the need for backend servers:

1. **Local Storage**: All persistent structures (local user settings, cached family profiles, synced calendars, and offline events) are stored locally in an encrypted SQLite database via `sqflite` (mobile), `sqflite_common_ffi` (desktop/tests), or `sqflite_common_ffi_web` (web) managed via `DatabaseService`.
2. **Local Route & ETA Solvers**: Driving routes are calculated in the driver's application using client-side Traveling Salesperson Problem (TSP) algorithms with Haversine distance calculations in `RouteOptimizerService`.
3. **iCal Fetching & Syncing**: Native Android, iOS, Desktop, and Web clients fetch external `.ics` feeds directly from calendar hosts, parsing them locally via `IcalParserService`.

---

## 3. Distributed Background iCal Coordination

To keep schedules up to date without a central server or duplicate network calls, clients coordinate background tasking using a lightweight state-locking protocol:

```text
┌────────────────┐         ┌────────────────┐         ┌───────────────────┐
│  Client App 1  │         │  Matrix Room   │         │ External iCal URL │
└───────┬────────┘         └───────┬────────┘         └─────────┬─────────┘
        │                          │                            │
        │ Wakes up in background   │                            │
        │                          │                            │
        ├─────────────────────────>│                            │
        │ Queries last sync time   │                            │
        │ (org.carpool.ical_lock)  │                            │
        │                          │                            │
        │ [Expired / Needs Sync]   │                            │
        │                          │                            │
        ├──────────────────────────┼───────────────────────────>│
        │                          │                            │ Fetches Raw .ics
        │                          │<───────────────────────────┤
        │                          │                            │
        │ Parses & Detects changes │                            │
        │                          │                            │
        ├─────────────────────────>│                            │
        │ Updates Schedule state   │                            │
        │ (org.carpool.schedules)  │                            │
        │                          │                            │
        ├─────────────────────────>│                            │
        │ Releases Lock            │                            │
        │ (org.carpool.ical_lock)  │                            │
```

### The iCal Lock State Protocol

To prevent multiple family members' background workers from hammering the same iCal feed simultaneously, clients use a Matrix State Event `org.carpool.ical_lock` to coordinate:

1. **State Event Structure (`org.carpool.ical_lock`)**:
   ```json
   {
     "last_sync_timestamp": 1698391800000,
     "synced_by": "@alice:matrix.org",
     "ical_feed_url": "https://sports-club.org/calendars/u10.ics"
   }
   ```
2. **Background Execution Loop**:
   * The OS background task runner wakes up the client app (e.g. every 4–6 hours).
   * The client fetches the current `org.carpool.ical_lock` state event from the Matrix Room.
   * If `currentTime - last_sync_timestamp` is less than the sync interval (e.g. 4 hours), the client immediately finishes (no work needed).
   * If the lock has expired, the client:
     1. Fetches the `.ics` file directly from the internet.
     2. Parses it locally using `IcalParserService`.
     3. Checks for new, updated, or canceled events.
     4. Publishes any delta changes as an updated `org.carpool.schedules` state event.
     5. Updates the `org.carpool.ical_lock` state event with the new timestamp and its Matrix ID.
3. **Matrix Native Push Notifications**: When an updated calendar event or cancelation notice is published to the room, the Matrix homeserver delivers native push notifications (via FCM/APNs) to all other group participants, updating their local offline databases immediately.

---

## 4. Real-Time Tracking & Dynamic ETA Calculations

When an active carpool starts, real-time location and dynamic ETA updates are achieved without paid third-party servers:

1. **High-Frequency Ephemeral Location Streaming**:
   * The driving client streams its current GPS coordinates every 15–30 seconds as standard Matrix room message events of type `org.carpool.location`.
   * These events are marked with a short Time-To-Live (TTL) or ignored in long-term room history threads to prevent bloating homeserver storage.
2. **Client-Side Dynamic ETA Engine**:
   * The driver's client is responsible for calculating remaining pick-up ETAs using `RouteOptimizerService`.
   * Using its current coordinates, the remaining waypoint coordinates, and a client-side routing algorithm (or straight-line Haversine calculation with local speed multipliers), the driver's client computes arrival times at each subsequent stop.
   * The driver's client publishes these computed ETAs directly within the `org.carpool.location` event payload.
   * **Receiving clients** read pre-computed ETAs from the incoming stream and display them natively, keeping coordinate rendering extremely fast and lightweight.

---

## 5. Matrix Device Management & End-to-End Encryption (E2EE)

To ensure privacy, encrypted message decryption, and device trust:

### Device Management Architecture
1. **Device ID Registration**: Every Matrix session login registers or reuses a unique `device_id` returned by `/_matrix/client/v3/login`.
2. **Device Key Upload & Query**:
   - Device keys (Curve25519 identity key and Ed25519 signing key) and one-time keys are uploaded via `/_matrix/client/v3/keys/upload`.
   - Other room participants' device keys are queried via `/_matrix/client/v3/keys/query`.
3. **Device Verification State Machine**:
   - Each user device is tracked locally with a verification state: `Verified`, `Unverified`, or `Blocked`.
   - Users can manage and verify current and remote devices from `SettingsScreen`.

```text
┌─────────────────────────┐        ┌─────────────────────────┐
│     Matrix Login        │ ──────>│ Persistent Device ID &  │
│  (returns device_id)    │        │ Matrix Access Token     │
└─────────────────────────┘        └────────────┬────────────┘
                                                │
                                                ▼
┌─────────────────────────┐        ┌─────────────────────────┐
│ Device Key Upload       │ <──────│ Matrix Device Registry  │
│ (/_matrix/client/v3/   │        │ GET /_matrix/client/v3/ │
│  keys/upload)           │        │     devices             │
└─────────────────────────┘        └─────────────────────────┘
```

### Room Encryption & Granular Location Privacy
- All private carpool circles are initialized with `m.room.encryption` (`algorithm: m.megolm.v1.aes-sha2`).
- Event payloads in encrypted rooms are wrapped in `m.room.encrypted` events.
- **Selective Location Disclosure (US-109, US-307)**: Family address coordinates are encrypted using ephemeral session keys that are released exclusively to the driver assigned to an active commute window, preventing broad disclosure of private family home locations to general room members.

---

## 6. Target Platforms & Runtime Specifications

* **Primary Runtime**: **Flutter SDK** (Targeting Android, iOS, Web, and Desktop).
* **UI Design Template & Material Components**: Built using Flutter **Material Design 3** (`useMaterial3: true`) with custom components (`NavigationBar`, `Card`, `Chip`, `SegmentedButton`, `EmptyStateWidget`) for consistent user experience across dark and light themes.
* **State Management**: **Provider** (`ChangeNotifierProvider`, `Consumer`) providing reactive state distribution across screens.
* **Database Driver**: **`sqflite`** for mobile platforms, **`sqflite_common_ffi`** for desktop and test execution, and **`sqflite_common_ffi_web`** for web browser execution.
