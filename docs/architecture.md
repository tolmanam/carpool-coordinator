# Technical Architecture & Design - Carpool Coordinator

This document defines the core architecture, decentralized philosophy, and platform constraints of the **Carpool Coordinator** application.

---

## 1. Decentralization Philosophy: Why Matrix?

To achieve **zero cloud hosting or database maintenance costs** and absolute privacy for families, we eliminate central application servers. Instead, we use **Matrix** (the open standard for secure, decentralized, real-time communication) as our virtual backend.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                          Mobile Client (Expo)                          │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │  iCal Schedule Puller   │            │  TSP Route Calculator   │   │
│   │   (Background Sync &    │            │ (In-app Heuristic TSP + │   │
│   │   State Coordination)   │            │   Dynamic ETA Engine)   │   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │  Local SQLite Storage   │            │    Matrix Client SDK    │   │
│   │   (expo-sqlite +        │            │ (Sync / Send Room State │   │
│   │    Drizzle ORM)         │            │    & Message Events)    │   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Matrix Client-Server HTTP API / WebSockets
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Decentralized Federated                         │
│                           Matrix Homeservers                           │
│                     (matrix.org, self-hosted, etc.)                    │
└────────────────────────────────────────────────────────────────────────┘
```

### Direct Mapping of Concepts

* **Identity & Authentication**: Users authenticate with any Matrix homeserver using their standard Matrix ID (`@user:server.org`) and credentials (Password or OIDC/SSO). No separate authentication or database server is required.
* **Family Group / Circle**: Modeled as a private, End-to-End Encrypted (E2EE) Matrix Room. Joining or being invited to a room represents joining a family coordination group.
* **State Sync**: Shared group profiles (member details, home coordinates) and destination configurations are stored directly in the room as standard **Matrix State Events** (`m.room.state`).
* **Schedules & Sign-ups**: Shifts and attendance sign-ups are shared as custom Matrix Message Events (`org.carpool.signup`).
* **Real-Time Coordinates & ETAs**: Streamed during active carpools as ephemeral, high-frequency, low-latency room messages (`org.carpool.location`).

---

## 2. Shift to Client-Side Processing

All heavy computational tasks are distributed to individual user devices, eliminating the need for backend servers:

1. **Local Storage**: All persistent structures (local user settings, cached family profiles, synced calendars, and offline events) are stored locally in an encrypted SQLite database via `expo-sqlite` and mapped with **Drizzle ORM**.
2. **Local Route & ETA Solvers**: Driving routes are calculated in the driver's application using client-side Traveling Salesperson Problem (TSP) algorithms.
3. **iCal Fetching & Syncing**: Native iOS and Android clients fetch external `.ics` feeds directly from calendar hosts, bypassing web browser CORS restrictions.

---

## 3. Distributed Background iCal Coordination

To keep schedules up to date without a central server or duplicate network calls, the clients coordinate background tasking using a lightweight state-locking protocol:

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

To prevent multiple family members' background workers from hammering the same iCal feed simultaneously, the clients use a Matrix State Event `org.carpool.ical_lock` to coordinate:

1. **State Event Structure (`org.carpool.ical_lock`)**:
   ```json
   {
     "last_sync_timestamp": 1698391800000,
     "synced_by": "@alice:matrix.org",
     "ical_feed_url": "https://sports-club.org/calendars/u10.ics"
   }
   ```
2. **Background Execution Loop**:
   * The OS background task runner wakes up the client app (e.g., every 4–6 hours).
   * The client fetches the current `org.carpool.ical_lock` state event from the Matrix Room.
   * If `currentTime - last_sync_timestamp` is **less** than the sync interval (e.g., 4 hours), the client immediately goes back to sleep (Task Complete, no work needed).
   * If the lock has expired, the client:
     1. Fetches the `.ics` file directly from the internet.
     2. Parses it locally.
     3. Checks for new, updated, or canceled events.
     4. Publishes any delta changes as an updated `org.carpool.schedules` state event (or a series of calendar events).
     5. Updates the `org.carpool.ical_lock` state event with the new timestamp and its own Matrix ID.
3. **Matrix Native Push Notifications**: When an updated calendar event or cancelation notice is published to the room, the Matrix homeserver instantly delivers native push notifications (via FCM/APNs) to all other group participants, updating their local offline databases immediately.

---

## 4. Real-Time Tracking & Dynamic ETA Calculations

When an active carpool starts, real-time location and dynamic ETA updates are achieved without paid third-party servers:

1. **High-Frequency Ephemeral Location Streaming**:
   * The driving client streams its current GPS coordinates every 15–30 seconds as standard Matrix room message events of type `org.carpool.location`.
   * These events are marked with a short Time-To-Live (TTL) or ignored in long-term room history threads to prevent bloating the homeserver storage.
2. **Client-Side Dynamic ETA Engine**:
   * The driver's client is responsible for calculating remaining pick-up ETAs.
   * Using its current coordinates, the remaining waypoint coordinates, and a client-side routing algorithm (or a straight-line Haversine fallback multiplied by a typical local traffic speed multiplier), the driver's client computes the arrival time at each subsequent stop.
   * The driver's client publishes these computed ETAs directly within the `org.carpool.location` event payload.
   * **Receiving clients** simply read the pre-computed ETAs from the incoming stream and display them natively. This eliminates the need for every passenger's client to perform continuous routing lookups and keeps coordinate rendering extremely fast and lightweight.

---

## 5. Matrix Device Management & End-to-End Encryption (E2EE)

To ensure privacy, encrypted message decryption, and device trust (modeled after clients like Cinny):

### Device Management Architecture
1. **Device ID Registration**: Every Matrix session login registers or reuses a unique `device_id` returned by `/_matrix/client/v3/login`.
2. **Device Key Upload & Query**:
   - Device keys (Curve25519 identity key and Ed25519 signing key) and one-time keys are uploaded via `/_matrix/client/v3/keys/upload`.
   - Other room participants' device keys are queried via `/_matrix/client/v3/keys/query`.
3. **Device Verification State Machine**:
   - Each user device is tracked locally with a verification state: `Verified`, `Unverified`, or `Blocked`.
   - Users can manage and verify current and remote devices from the Settings interface.

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

### Room Encryption
- All private carpool circles are initialized with `m.room.encryption` (`algorithm: m.megolm.v1.aes-sha2`).
- Event payloads in encrypted rooms are wrapped in `m.room.encrypted` events.

---

## 6. Target Platforms & Runtime Specifications

* **Primary Runtime**: React Native / Expo.
* **Native Builds**: Expo Development Builds (`npx expo prebuild`) to support native SQLite (`expo-sqlite`) and secure persistent store layers.
* **UI Design Template & Material Components**: Built using **React Native Paper** for Material Design 3 (MD3) components (cards, chips, segmented buttons, banners, surfaces, themed text inputs, and icons) on Android and iOS devices.
* **Routing System**: File-based **Expo Router** for screen-to-screen navigation and strict type-safety.
* **Web Companion Support**: Designed with native mobile first. Web support is relegated to an optional Phase 2, bypassing CORS limitations via Matrix Room Media or lightweight serverless CORS proxies.
