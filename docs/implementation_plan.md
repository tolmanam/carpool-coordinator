# Master Implementation Plan - Carpool Coordinator

This document is the official, comprehensive blueprint for implementing the **Carpool Coordinator** application using Flutter, Dart, SQLite (`sqflite`), Provider, and Matrix.

---

## 1. System Requirements & Tech Stack

The application strictly conforms to this technology stack:
- **Framework**: **Flutter SDK** (v3.41+ stable) / **Dart SDK** (v3.11+).
- **Architecture**: Clean, decentralized, offline-first mobile client architecture with state management powered by **Provider**.
- **UI & Styling**: **Material Design 3** (`useMaterial3: true`), responsive navigation bar, light/dark themes, accessible high-contrast indicators, clear empty state placeholders (`EmptyStateWidget`).
- **Local Database**: **`sqflite`** (Mobile) / **`sqflite_common_ffi`** (Desktop/Tests) / **`sqflite_common_ffi_web`** (Web) managed via `DatabaseService` (`lib/services/database_service.dart`).
- **Secure Credentials**: **`flutter_secure_storage`** or SharedPreferences for Matrix access tokens and local cryptographic key material.
- **Calendar Parsing**: **`icalendar_parser`** or client-side RFC 5545 string parser (`lib/services/ical_parser_service.dart`).
- **Matrix Integration**: Direct REST client wrapper (`lib/services/matrix_service.dart`) over Matrix Client-Server API v3 (`/_matrix/client/v3/`) with homeserver auto-discovery (`/.well-known/matrix/client`), SSO/OIDC authentication support, long-polling sync loop with exponential backoff, E2EE device key upload/query (`/keys/upload`, `/keys/query`), and offline event queueing.

---

## 2. Core UI/UX Expectations & Navigation Structure

The design is accessible, offline-first, high-contrast, and intuitive for busy parents, drivers, and coordinators.

### A. Key UI/UX Principles
1. **Offline First & Seamless Resilience**: Full offline capability for schedules, routes, organization circles, family management, and local chats. Offline status badges/toggles are deliberately omitted from user screens to keep the interface clean; actions queue in local SQLite database tables and sync automatically upon reconnection.
2. **Optimistic UI Updates**: Toggling ride signups, volunteering as driver, creating members, or updating routes instantly updates local SQLite state and UI providers before dispatching Matrix events in the background.
3. **Dual-Role Fluidity**: Seamless tab navigation allowing parents, drivers, and activity coordinators to switch between family administration, event scheduling, active route driving, and group chat.

### B. Screen & Directory Structure (`lib/`)
* `lib/main.dart` - Entry point configuring Material Design 3 light/dark themes, Provider initialization, and top-level routing.
* `lib/models/models.dart` - Structured data models (`Family`, `FamilyMember`, `Organization`, `CarpoolCircle`, `OrganizationParticipant`, `Schedule`, `Signup`, `LocalIcalEvent`, `RouteWaypoint`, `ChatMessage`).
* `lib/screens/login_screen.dart` - Matrix login interface (Homeserver discovery, Username/Password auth, federated SSO redirect/token login).
* `lib/screens/main_tab_screen.dart` - Bottom `NavigationBar` root tab container (Schedule, Circles, Active Route, Settings).
* `lib/screens/schedule_screen.dart` - Interactive timeline listing iCal occurrences, ride/drive signups, seat capacity caps, and active route triggers.
* `lib/screens/circles_screen.dart` - Organization space and Carpool Circle roster, email/mailto invites, participant assignment, and Matrix group chat.
* `lib/screens/active_route_screen.dart` - Live TSP route navigation, driver GPS location updates, waypoint check-ins, and delay alerts.
* `lib/screens/settings_screen.dart` - Profile administration, home address & co-parenting coordinates configuration, theme switcher, and Matrix device verification keys management.
* `lib/services/database_service.dart` - Central SQLite persistence layer with migration support and CRUD operations across all entities.
* `lib/services/matrix_service.dart` - Matrix Client-Server HTTP API implementation, long-polling sync, offline event queueing, and room state management.
* `lib/services/ical_parser_service.dart` - Client-side RFC 5545 iCalendar feed parser and occurrence expander.
* `lib/services/route_optimizer_service.dart` - Greedy Traveling Salesperson Problem (TSP) solver using Haversine distance formula and ETA offset calculations.

---

## 3. Strict Testing Matrix

All implementations feature automated unit and widget tests located in `test/`:
1. **Database Persistence (`test/database_service_test.dart`)**:
   - Verify table initialization, migrations, and cascading deletions (e.g. deleting a family purges member and participant records).
   - Test offline queueing and database purges on logout.
2. **iCal Feed Parsing (`test/ical_parser_service_test.dart`)**:
   - Parse RFC 5545 `.ics` feeds with single and recurring (`RRULE`) rules into local `LocalIcalEvent` instances.
3. **TSP Route Optimization (`test/route_optimizer_service_test.dart`)**:
   - Feed passenger GPS coordinates and activity destination into `RouteOptimizerService`.
   - Verify TSP waypoint ordering and departure ETA offset back-calculations.
4. **User Story & Scenario Matrix Coverage (`test/user_stories_test.dart`)**:
   - Unit and integration tests validating all user stories (US-101 through US-406) and dual-role scenarios (C-1 through C-7).

---

## 4. Phased Step-by-Step Execution Map

### Phase 1: Local-First Core & Database Architecture
* **Goal**: Build local offline database, iCal feed parser, and core models.
* **Covered Stories**: US-101, US-102, US-106, US-403, US-406.
* **Tasks**:
  1. Initialize Flutter project with Material 3 and Provider dependencies in `pubspec.yaml`.
  2. Implement `DatabaseService` (`lib/services/database_service.dart`) using `sqflite` with SQLite schemas for families, members, organizations, circles, schedules, signups, route waypoints, chat messages, and offline events.
  3. Implement data models in `lib/models/models.dart`.
  4. Develop client-side RFC 5545 iCal parser in `lib/services/ical_parser_service.dart`.
  5. Build `ScheduleScreen` displaying offline iCal events and local signups.

### Phase 2: Matrix HTTP Sync Engine & Group Coordination
* **Goal**: Enable Matrix REST API authentication, sync loop, room state events, and messaging.
* **Covered Stories**: US-103, US-104, US-105, US-107, US-201, US-205, US-301, US-302, US-305, US-401, US-402, C-1, C-2, C-3, C-4, C-5.
* **Tasks**:
  1. Build `MatrixService` handling homeserver auto-discovery (`/.well-known/matrix/client`), SSO login, token auth, sync polling, and offline event queueing.
  2. Map Matrix Spaces (`m.space`) for Organizations and child rooms (`m.space.child`) for Carpool Circles.
  3. Implement `org.carpool.signup` state events for ride and driver signups.
  4. Develop `CirclesScreen` featuring circle management, participant assignment, email `mailto:` invites, and group chat (`m.room.message`).
  5. Support driver replacement and ride cancellations with optimistic SQLite updates.

### Phase 3: Route Optimizer, Seat Capacities, and Active Route Interface
* **Goal**: Implement TSP route solver, vehicle seat limits, live tracking, and delay alerts.
* **Covered Stories**: US-202, US-203, US-204, US-206, US-207.
* **Tasks**:
  1. Implement Haversine-based TSP route optimizer in `RouteOptimizerService`.
  2. Add `seat_capacity` enforcement in `Signup` model and UI to cap passenger signups automatically when full.
  3. Develop `ActiveRouteScreen` displaying TSP pickup order, dynamic ETAs, waypoint check-ins, and 5-10 minute delay alerts (`org.carpool.alert`).
  4. Support offline queueing for location updates and delay alerts when connection drops.

### Phase 4: Distributed iCal Lock Protocol & Matrix Device Key Verification
* **Goal**: Coordinate background iCal sync across devices and implement E2EE key management.
* **Covered Stories**: US-303, US-304, US-404, US-405.
* **Tasks**:
  1. Implement `org.carpool.ical_lock` state protocol in `MatrixService` to prevent redundant feed fetches across devices.
  2. Build Matrix device key upload/query (`/keys/upload`, `/keys/query`) and verification controls in `SettingsScreen`.
  3. Implement theme customization (Light/Dark/System Default) and notification settings.

### Phase 5: Advanced Family Administration, Co-Parenting & Safety Capabilities
* **Goal**: Complete advanced family administration features, multi-household custody schedules, and child safety controls.
* **Covered Stories**: US-108, US-109, US-110, US-111, US-112, US-113, C-6, C-7.
* **Tasks**:
  1. **Co-Parenting Multi-Household Scheduling (US-108, Scenario C-6)**: Extend family member profiles to support day-of-week home pickup addresses/coordinates. Integrate custody schedule logic into `RouteOptimizerService` to select the active home address dynamically for TSP calculations.
  2. **Location Data Minimization (US-109)**: Restrict exact address and coordinate disclosures using driver-scoped E2EE keys so family coordinates are decrypted exclusively by the assigned driver during active commute windows.
  3. **Child Safety, Booster Seat & Medical Notes (US-110)**: Add booster seat flags, medical notes, and allergy alerts to child profiles. Display safety badges on `ActiveRouteScreen` for assigned drivers.
  4. **Pickup & Drop-off Hand-off Verification (US-111)**: Implement real-time check-in confirmation buttons on `ActiveRouteScreen` dispatching `org.carpool.checkin` state events to notify parents upon safe arrival.
  5. **Delegated Helper / Babysitter Permissions (US-112, Scenario C-7)**: Implement temporary helper tokens allowing trusted non-family adults to drive or perform pickups without accessing family administration settings.
  6. **Schedule Conflict & Overlap Detection (US-113)**: Add multi-child schedule conflict analysis in `IcalParserService` to highlight overlapping commitments visually in `ScheduleScreen`.

### Phase 6: Organization Coordinator Tools & Leadership Delegation
* **Goal**: Provide low-burden onboarding, logistics tracking, multi-calendar support, emergency broadcasts, and zero-backend leadership handoff.
* **Covered Stories**: US-306, US-307, US-308, US-309, US-310, US-311, US-312, US-313.
* **Tasks**:
  1. **Self-Service Onboarding & Data Offboarding (US-306)**: Generate shareable `matrix.to` QR codes and invite links. Enable self-service profile deletion and data purging.
  2. **Selective Location Disclosure Enforcement (US-307)**: Enforce space-wide privacy policies restricting home address visibility to assigned drivers during active rides.
  3. **Equipment & Seat Logistics Requirements (US-308)**: Add equipment tags (sports gear, instruments) and booster seat counts to signups; enforce vehicle cargo and seat capacity limits.
  4. **Multi-Calendar Feeds & Direct Matrix Announcements (US-309, US-311)**: Support multiple iCal feed URLs per Organization and dispatch high-priority direct Matrix announcements (`org.carpool.schedule_announcement`, `org.carpool.urgent_alert`).
  5. **Dynamic Emergency Contact & Medical Access (US-310)**: Reveal emergency contacts and medical notes strictly to assigned drivers during active route execution.
  6. **Attendance Tracking & Commute Headcount Verification (US-312)**: Implement check-in/check-out logs for drivers to confirm participant boarding and drop-off timestamps.
  7. **Leadership Handoff & Delegated Moderation (US-313)**: Update Matrix room power levels (`m.room.power_levels`) to assign co-coordinators or transfer Organization space ownership seamlessly without central servers.

### Phase 8: Advanced Driver Safety, Liability & Social Dynamics
* **Goal**: Expand driver capability, social boundary enforcement, liability attestation, and child safety handoffs.
* **Tasks**:
  1. **Route Impact Preview & Detour Limits (US-208)**: Add TSP delta pre-calculation and configurable driver detour thresholds (e.g. +15 mins max detour limit).
  2. **Automated Seat Allocation & Objective Capping (US-209)**: Build rule engine for first-come/proximity seat allocation and automatic signup closure.
  3. **Driver Credential & Liability Attestation (US-210)**: Create encrypted storage for driver license/insurance confirmation and annual organization liability terms.
  4. **Booster Seat & Safety Equipment Verification (US-211)**: Match child safety equipment needs (booster seat/rear-facing) against vehicle equipment capabilities.
  5. **Pickup & Drop-off Handoff Verification (US-212)**: Implement adult check-in / pin-verify handoffs at pickup points and destination delivery confirmations.
  6. **Emergency Route Handoff & Segment Transfer (US-213)**: Build driver-to-driver route segment transfer protocol for emergency situations.


---

## 5. Mobile Deployment & Build Workflow

1. **Android Target Configuration**: Application ID `org.carpool.coordinator` defined in `android/app/build.gradle.kts` and `AndroidManifest.xml`.
2. **CI/CD Workflows**:
   - GitLab CI (`.gitlab-ci.yml`) runs `flutter test` and compiles release APKs.
   - GitHub Actions (`.github/workflows/ci.yml`, `cd.yml`, `deploy_web.yml`) run quality checks, build Android release APKs, and deploy the Web PWA.
3. **Compile Release APK**:
   ```bash
   flutter build apk --release
   ```
