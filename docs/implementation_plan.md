# Master AI Agent Implementation Plan - Carpool Coordinator

This document is the official, comprehensive blueprint for an AI coding agent to implement the Carpool Coordinator.

---

## 1. System Requirements & Tech Stack

The coding agent must build the application strictly conforming to this stack:
- **Framework**: React Native with **Expo SDK 51+** (using Expo Development Builds for custom native modules).
- **Navigation**: **Expo Router** (v3+, file-based layout).
- **UI Styling**: **NativeWind (Tailwind CSS for React Native)** or custom stylesheet-guided native components, with high contrast light/dark indicators.
- **Local Storage**: **`expo-sqlite`** + **`drizzle-orm`** (with SQLite backend).
- **Secure Credentials**: **`expo-secure-store`** for Matrix access tokens and local SQLite database encryption keys.
- **Calendar Parsing**: **`ical.js`** or raw client-side RFC 5545 string-to-JSON parser.
- **Matrix Integration**: Standard **Matrix Client-Server HTTP API** requests (direct REST client wrapper to avoid native library link dependencies) or standard **`matrix-js-sdk`**.

---

## 2. Core UI/UX Expectations

The design should be accessible, high-contrast, offline-first, and highly intuitive for busy parents.

### A. General Design Principles
1. **Offline Indicator**: A clear persistent badge or banner in the header showing the current online/offline state of the Matrix client.
2. **Sync Pulse**: A subtle, non-intrusive status indicator when the local SQLite cache is syncing changes with the Matrix room.
3. **Optimistic UI Updates**: Buttons like "Ride" or "Drive" must instantly toggle state on the screen immediately, updating the local SQLite DB, then queueing the Matrix message dispatch in the background.

### B. Screen Breakdown (Expo Router Structure)
* `app/index.tsx` - Login screen (Simple form: Homeserver URL, Username, Password, OIDC SSO button).
* `app/(tabs)/_layout.tsx` - Root Tab Navigator layout (Bottom tabs: Schedule, Circles, Settings).
* `app/(tabs)/schedule.tsx` - The Daily/Weekly timeline. Lists occurrences from parsed iCal feeds. Displays:
  - Date & event title (e.g., "U10 Soccer Practice").
  - Current signups ("Riders: John, Sarah", "Driver: Alice").
  - Finalized route departure time and CTA to view live stream if active.
  - Interactive "Ride / Drive" buttons.
* `app/(tabs)/circles.tsx` - List of configured coordination circles (Matrix rooms). Includes "Create Circle" and "Invite Member" interfaces.
* `app/(tabs)/settings.tsx` - Profile info, Home address configuration (with visual address check/pin drop), iCal URLs setup, and logout.
* `app/route-active.tsx` - Active Carpool Map Screen (using `react-native-maps`). Displays:
  - **For Drivers**: GPS center toggle, "Start Drive" button, current waypoint details, and immediate delay reports.
  - **For Passengers**: The driver's streaming real-time pin, the route polyline, and the precalculated dynamic ETA countdown.

---

## 3. Strict Testing Matrix

All implementations must feature high-coverage automated unit tests.

### Required Tests
1. **Local SQLite Migrations & Queries**:
   - Write tests confirming tables are initialized correctly.
   - Verify that inserts, updates, and cascading deletions (e.g., deleting a family profile deletes its members) function exactly as planned.
2. **iCal Parser Integrity (`ical.js` / custom parser)**:
   - Provide a mock `.ics` text file containing standard single and recurring rules (`RRULE`).
   - Run tests ensuring standard occurrences are resolved to accurate local timestamp ranges.
3. **TSP Route Optimizer Solver**:
   - Write unit tests feeding mock latitude/longitude coordinates of 3-5 passengers and a soccer field destination.
   - Assert that `solveOptimalRoute` organizes the waypoints sequentially by nearest neighbor and back-calculates accurate departure offset offsets.
4. **Offline Sync & Reconciliation Engine**:
   - Mock standard Matrix `/sync` chunk responses.
   - Assert that when receiving a collection of state/message events, the database engine executes correct atomic upsert operations on SQLite.

---

## 4. Phased Step-by-Step Execution Map

The coding agent should implement the features in the following precise sequence:

### Phase 1: Local-First Core & Database Setup
* **Goal**: Build the offline database, local iCal loader, and navigation schema.
* **Tasks**:
  1. Initialize Expo project with Expo Router template.
  2. Install `expo-sqlite` and `drizzle-orm`. Set up database connections and schema files.
  3. Write local unit tests for SQLite tables and seed data.
  4. Build the client-side iCal string parser. Write tests verifying parsing of diverse recurrence types.
  5. Code the Schedule screen, rendering parsed local iCal entries offline.

### Phase 2: Matrix HTTP Engine (Unencrypted Room Integration)
* **Goal**: Establish direct client communication with Matrix servers.
* **Tasks**:
  1. Build a lightweight Matrix Client helper implementing authentication (`POST /login`), state polling (`GET /sync`), sending state events (`PUT /state`), and sending room messages (`POST /send`).
  2. Implement local state sync: whenever `/sync` returns data, parse incoming events of type `org.carpool.*` and sync them down to Drizzle SQLite tables.
  3. Add Group Management: screen interfaces to create rooms (circles) and trigger member invites.
  4. Implement SignUp: tapping "Ride/Drive" publishes `org.carpool.signup` messages to the room and registers them in the local DB.

### Phase 3: Route Solver & Active Carpool Interface
* **Goal**: Build the routing engine and the live tracking experience.
* **Tasks**:
  1. Program the heuristic TSP Solver in pure JS (Haversine formula based). Unit test extensively.
  2. Create the "Route Generation" hook: the assigned driver compiles signups, calculates the waypoint list, and publishes an `org.carpool.route` message.
  3. Set up the Active Carpool navigation screen utilizing `react-native-maps`.
  4. Code the background geofence/location emitter (using `expo-location` and `expo-task-manager`) to stream driver coordinates as `org.carpool.location` messages.
  5. Program the receiving view: passenger clients listen to the location stream, render the driver's current position, and show precomputed dynamic ETAs.

### Phase 4: Distributed Background Sync Worker & Delays
* **Goal**: Implement distributed task orchestration.
* **Tasks**:
  1. Setup `expo-background-fetch` tasks.
  2. Implement the state lock protocol (`org.carpool.ical_lock`): check if recent sync occurred, attempt lock write, fetch external feed, parse, and upload updated state list to Matrix.
  3. Integrate automatic late-arrival warning alerts: when driving client ticks, trigger delay-alert messages if the delay exceeds 5 minutes.

### Phase 5: Progressive Cryptography (E2EE Activation)
* **Goal**: Maximize privacy controls.
* **Tasks**:
  1. Secure SQLite data at rest by binding the db instance with a local device encryption key managed via `expo-secure-store`.
  2. Implement secure OIDC/SSO authentication flow.
  3. Activate E2EE: establish standard Olm/Megolm end-to-end room encryption for all `org.carpool.*` communication, ensuring all children coordinates, profile names, and schedules remain encrypted and hidden from homeserver admins.
