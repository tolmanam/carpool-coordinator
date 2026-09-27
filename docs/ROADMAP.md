# Carpool Coordinator - Feature Roadmap & Technical Tracking

This document serves as the official, living roadmap and technical tracking guide for developers and AI agents working on the **Carpool Coordinator** repository. It breaks down each phase from the Master Implementation Plan, Architecture Specification, and User Stories into specific deliverable and testable features.

---

## 📌 Status Legend & Evaluation Criteria
- `[x]` **Completed**: Feature logic exists in `lib/` AND is verified by passing automated unit/widget tests in `test/`.
- `[ ]` **Pending / In Progress**: Feature is planned, partially implemented, or lacks comprehensive automated unit test coverage.

---

## 🗺️ Master Phase Breakdown

### Phase 1: Local-First Core & Database Architecture
*Focus: Offline SQLite persistence, RFC 5545 calendar parsing, core data models, and primary schedule views.*

- [x] **Project Initialization & Dependency Setup**
  - **Details**: Configure Flutter project with Material Design 3 (`useMaterial3: true`), `provider`, `sqflite`, `sqflite_common_ffi`, `sqflite_common_ffi_web`, `shared_preferences`, and `http`.
  - **User Stories**: US-403, US-404
  - **Implementation**: `pubspec.yaml`, `lib/main.dart`
  - **Test**: `test/widgets_test.dart`

- [x] **Local SQLite Persistence Layer (`DatabaseService`)**
  - **Details**: SQLite schema creation and CRUD operations for `families`, `family_members`, `organizations`, `carpool_circles`, `organization_participants`, `schedules`, `signups`, `local_ical_events`, `route_waypoints`, `chat_messages`, and `pending_offline_events`. Supports cascading purges and migrations.
  - **User Stories**: US-101, US-102, US-104, US-403, US-406
  - **Implementation**: `lib/services/database_service.dart`
  - **Test**: `test/database_service_test.dart`

- [x] **Core Data Models**
  - **Details**: Immutable Dart models with JSON/Map serialization and deserialization for all application domain entities (`Family`, `FamilyMember`, `Organization`, `CarpoolCircle`, `OrganizationParticipant`, `Schedule`, `Signup`, `LocalIcalEvent`, `RouteWaypoint`, `ChatMessage`).
  - **User Stories**: US-101, US-102, US-106, US-107, US-206
  - **Implementation**: `lib/models/models.dart`
  - **Test**: `test/database_service_test.dart`, `test/user_stories_test.dart`

- [x] **Client-Side RFC 5545 iCal Parser (`IcalParserService`)**
  - **Details**: Parse raw `.ics` calendar feed strings locally, expand recurring events (`RRULE`), and persist occurrences into local SQLite as `LocalIcalEvent` objects without external backend dependencies.
  - **User Stories**: US-301, US-303
  - **Implementation**: `lib/services/ical_parser_service.dart`
  - **Test**: `test/ical_parser_service_test.dart`

- [x] **Schedule & Calendar Timeline Interface (`ScheduleScreen`)**
  - **Details**: Interactive UI displaying upcoming iCal occurrences, rider signups, driver registrations, seat capacity indicators, and trigger buttons for active driving.
  - **User Stories**: US-105, US-201, US-205, US-206
  - **Implementation**: `lib/screens/schedule_screen.dart`
  - **Test**: `test/user_stories_test.dart`

---

### Phase 2: Matrix HTTP Sync Engine & Group Coordination
*Focus: Direct REST client wrapper over Matrix v3 API, space hierarchies, room chat, and signup event synchronization.*

- [x] **Matrix REST Service & Authentication (`MatrixService`)**
  - **Details**: Client-server API (`/_matrix/client/v3/`) integration supporting homeserver well-known auto-discovery (`/.well-known/matrix/client`), SSO/OIDC redirects, password authentication, 401 session invalidation, long-polling sync loop with exponential backoff, rate limit handling (429), and offline event queueing.
  - **User Stories**: US-401, US-403
  - **Implementation**: `lib/services/matrix_service.dart`, `lib/screens/login_screen.dart`
  - **Test**: `test/matrix_service_test.dart`

- [x] **Matrix Space Hierarchy (Organizations & Circles)**
  - **Details**: Represent Organizations as Matrix Spaces (`m.space`) tagged with `org.carpool.organization` metadata, and Carpool Circles as child rooms (`m.space.child`). Support client-side `mailto:` invitation generation containing `matrix.to` links.
  - **User Stories**: US-103, US-301, US-302, Scenarios C-2, C-3
  - **Implementation**: `lib/services/matrix_service.dart`, `lib/screens/circles_screen.dart`
  - **Test**: `test/user_stories_test.dart`

- [x] **Signup Matrix Custom Events (`org.carpool.signup`)**
  - **Details**: Publish and sync ride signups and driver registrations as custom Matrix state events. Support optimistic local updates and background sync.
  - **User Stories**: US-105, US-201, US-205
  - **Implementation**: `lib/services/matrix_service.dart`, `lib/screens/schedule_screen.dart`
  - **Test**: `test/user_stories_test.dart`

- [x] **In-App Matrix Group Chat (`m.room.message`)**
  - **Details**: Send and display text messages inside Family, Organization, and Circle rooms. Store messages in local SQLite for offline access.
  - **User Stories**: US-402
  - **Implementation**: `lib/screens/circles_screen.dart`, `lib/services/database_service.dart`
  - **Test**: `test/database_service_test.dart`

- [x] **Driver Replacement & Ride Opt-Out Workflow**
  - **Details**: Drivers can unassign themselves from a scheduled drive; parents can opt out child ride signups. Local database updates immediately and dispatches custom state events to Matrix.
  - **User Stories**: US-105, US-205
  - **Implementation**: `lib/screens/schedule_screen.dart`, `lib/services/database_service.dart`
  - **Test**: `test/user_stories_test.dart`

---

### Phase 3: Route Optimizer, Seat Capacities, and Active Route Interface
*Focus: Client-side TSP route optimization, vehicle seat capacity enforcement, active driving mode, location streaming, and delay alerts.*

- [x] **Client-Side TSP Route Optimizer (`RouteOptimizerService`)**
  - **Details**: Greedy Traveling Salesperson Problem (TSP) solver using Haversine distance formula to calculate optimal pickup order and departure ETA offset back-calculations based on passenger home coordinates and target activity destination.
  - **User Stories**: US-202
  - **Implementation**: `lib/services/route_optimizer_service.dart`
  - **Test**: `test/route_optimizer_service_test.dart`

- [x] **Vehicle Seat Capacity Enforcement**
  - **Details**: Include `seat_capacity` attribute in driver signup registrations; automatically cap passenger ride signups on the UI when the vehicle capacity is reached.
  - **User Stories**: US-206
  - **Implementation**: `lib/models/models.dart`, `lib/screens/schedule_screen.dart`
  - **Test**: `test/user_stories_test.dart`

- [x] **Active Route Screen & Live GPS Location Streaming**
  - **Details**: Interface displaying TSP pickup order, dynamic ETAs, waypoint check-in buttons, and high-frequency GPS position streaming (`org.carpool.location`) to the Matrix room.
  - **User Stories**: US-203
  - **Implementation**: `lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`
  - **Test**: `test/matrix_service_test.dart`

- [x] **Delay Alerts & Offline Location Event Queueing**
  - **Details**: Driver delay trigger dispatches `org.carpool.alert` room messages (e.g. +5/10 min delay). When offline, alerts and location events queue in SQLite (`pending_offline_events`) and flush automatically upon network restoration.
  - **User Stories**: US-204, US-207
  - **Implementation**: `lib/screens/active_route_screen.dart`, `lib/services/database_service.dart`, `lib/services/matrix_service.dart`
  - **Test**: `test/user_stories_test.dart`, `test/matrix_service_test.dart`

---

### Phase 4: Distributed iCal Lock Protocol & Matrix Device Key Verification
*Focus: Multi-device background sync coordination, E2EE key inspection, and user preference controls.*

- [x] **Distributed iCal Lock Protocol (`org.carpool.ical_lock`)**
  - **Details**: State event protocol ensuring only one device fetches external `.ics` feeds per time interval, avoiding redundant network requests and duplicate sync processing.
  - **User Stories**: US-304
  - **Implementation**: `lib/services/matrix_service.dart`
  - **Test**: `test/user_stories_test.dart`

- [x] **Matrix Device Management & Key Verification Controls**
  - **Details**: Fetch device listings (`/_matrix/client/v3/devices`), upload device keys (`/keys/upload`), query remote device keys (`/keys/query`), and toggle device verification status in Settings.
  - **User Stories**: US-405
  - **Implementation**: `lib/services/matrix_service.dart`, `lib/screens/settings_screen.dart`
  - **Test**: `test/matrix_service_test.dart`

- [x] **Theme Switcher & App Settings (`SettingsScreen`)**
  - **Details**: Toggle Light, Dark, and System Default themes via Material 3 theme provider. Display account status, homeserver details, build metadata (`AppInfo`), and logout reset controls.
  - **User Stories**: US-404, US-406
  - **Implementation**: `lib/screens/settings_screen.dart`, `lib/config/app_info.dart`, `lib/widgets/about_app_dialog.dart`
  - **Test**: `test/app_info_test.dart`, `test/user_stories_test.dart`

---

### Phase 5: Advanced Family Administration, Co-Parenting & Safety Capabilities
*Focus: Co-parenting multi-household support, location privacy controls, child safety attributes, and hand-off confirmations.*

- [x] **Co-Parenting Multi-Household Scheduling (US-108, Scenario C-6)**
  - **Details**: Extend `FamilyMember` data model and SQLite schema to support day-of-week home pickup addresses/coordinates (e.g. Household A on Mon/Wed, Household B on Tue/Thu). Integrate custody schedule logic into `RouteOptimizerService` to dynamically select the active pickup location based on the event date.
  - **User Stories**: US-108, Scenario C-6
  - **Target Files**: `lib/models/models.dart`, `lib/services/database_service.dart`, `lib/services/route_optimizer_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Location Data Minimization & Scoped E2EE Sharing (US-109)**
  - **Details**: Encrypt exact home address and coordinate payload in Matrix events (`org.carpool.location_encrypted`), ensuring coordinates are shared strictly with the assigned driver during active commute windows.
  - **User Stories**: US-109, US-307
  - **Target Files**: `lib/services/matrix_service.dart`, `lib/screens/active_route_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Child Safety, Booster Seat & Medical Notes (US-110)**
  - **Details**: Add `requires_booster_seat` (boolean) and `medical_notes` (text) fields to `FamilyMember` model and SQLite schema. Display prominent safety badges and medical alert indicators on `ActiveRouteScreen` for assigned drivers.
  - **User Stories**: US-110
  - **Target Files**: `lib/models/models.dart`, `lib/services/database_service.dart`, `lib/screens/active_route_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Pickup & Drop-off Hand-off Verification (US-111)**
  - **Details**: Real-time hand-off check-in buttons on `ActiveRouteScreen` dispatching `org.carpool.checkin` state events (e.g. "Child Boarded", "Child Delivered") to notify parents instantly via Matrix room updates.
  - **User Stories**: US-111
  - **Target Files**: `lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Delegated Helper / Babysitter Permissions (US-112, Scenario C-7)**
  - **Details**: Support scoped temporary helper profiles (`is_delegated_helper`, role `'helper'`) allowing trusted non-family adults (grandparents, babysitters) to drive or perform pickups without granting full family administration rights.
  - **User Stories**: US-112, Scenario C-7
  - **Target Files**: `lib/models/models.dart`, `lib/services/database_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Schedule Conflict & Overlap Detection (US-113)**
  - **Details**: Multi-child schedule overlap analysis in `IcalParserService` and `ScheduleScreen` to highlight conflicting event commitments visually and prompt parents to organize carpooling early.
  - **User Stories**: US-113
  - **Target Files**: `lib/services/ical_parser_service.dart`, `lib/screens/schedule_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

---

### Phase 6: Organization Coordinator Tools & Leadership Delegation
*Focus: QR/link onboarding, selective location privacy policies, multi-calendar feeds, emergency broadcasts, and zero-backend leadership handoff.*

- [x] **Self-Service Onboarding & Profile Offboarding (US-306)**
  - **Details**: Generate shareable `matrix.to` QR codes and deep links for circle joining. Provide self-service profile deletion and data purging triggers on logout/offboarding.
  - **User Stories**: US-306
  - **Target Files**: `lib/screens/circles_screen.dart`, `lib/services/database_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Space-Wide Selective Location Disclosure Policies (US-307)**
  - **Details**: Organization-level settings to enforce space-wide address privacy, preventing non-driver circle members from accessing family street addresses.
  - **User Stories**: US-307
  - **Target Files**: `lib/services/matrix_service.dart`, `lib/screens/circles_screen.dart`
  - **Test Target**: `test/matrix_service_test.dart`, `test/user_stories_test.dart`

- [x] **Equipment & Cargo Logistics Requirements (US-308)**
  - **Details**: Attach equipment tags (sports gear, musical instruments) and booster seat counts to ride signups; check driver vehicle cargo capacity before confirming passenger signups.
  - **User Stories**: US-308
  - **Target Files**: `lib/models/models.dart`, `lib/screens/schedule_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Multi-Calendar Feeds & Direct Matrix Announcements (US-309, US-311)**
  - **Details**: Support multiple `.ics` feed URLs per Organization. Implement `org.carpool.schedule_announcement` and `org.carpool.urgent_alert` high-priority event dispatching for ad-hoc schedule changes or weather cancellations.
  - **User Stories**: US-309, US-311
  - **Target Files**: `lib/services/matrix_service.dart`, `lib/services/ical_parser_service.dart`, `lib/screens/schedule_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Dynamic Emergency Contact & Medical Access Control (US-310)**
  - **Details**: Restrict emergency contacts and child medical notes so they are visible exclusively to the assigned driver during active route execution window.
  - **User Stories**: US-310
  - **Target Files**: `lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Attendance Tracking & Commute Headcount Verification (US-312)**
  - **Details**: Record driver pickup and drop-off timestamps per participant (`org.carpool.checkin`) to maintain verifiable attendance logs for coordinators and parents.
  - **User Stories**: US-312
  - **Target Files**: `lib/screens/active_route_screen.dart`, `lib/services/database_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [x] **Zero-Backend Leadership Handoff & Delegated Moderation (US-313)**
  - **Details**: Manage Matrix room power levels (`m.room.power_levels`) to promote co-coordinators or transfer Organization space ownership seamlessly without central servers.
  - **User Stories**: US-313
  - **Target Files**: `lib/services/matrix_service.dart`, `lib/screens/circles_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

---

### Phase 7: Native Matrix Rust SDK Integration & Background Streaming
*Focus: Zero-trust end-to-end Megolm encryption via matrix-rust-sdk FFI bindings, native background location streaming, and Matrix Push Gateway integration.*

- [ ] **Native `matrix-rust-sdk` FFI Bindings**
  - **Details**: Bind native Rust SDK for client-side zero-trust Olm/Megolm E2EE encrypted sync, key exchange, and room state management across Android and iOS.
  - **Target Files**: `lib/services/matrix_service.dart`, native binding configuration files
  - **Test Target**: `test/matrix_service_test.dart`

- [ ] **Background Location Streaming & Matrix Push Gateway**
  - **Details**: Implement native Android background service (`flutter_background_service`) for uninterrupted active drive GPS streaming and Matrix Push Gateway notifications (via FCM/APNs) for high-priority delay alerts.
  - **Target Files**: `lib/services/matrix_service.dart`, `android/app/src/main/AndroidManifest.xml`
  - **Test Target**: `test/matrix_service_test.dart`

---

### Phase 8: Advanced Driver Safety, Liability & Social Dynamics
*Focus: Detour thresholds, objective seat capping rules, driver credential attestation, child equipment verification, and emergency route transfers.*

- [ ] **Route Impact Preview & Detour Thresholds (US-208)**
  - **Details**: Pre-calculate pickup route time/distance delta before driver confirmation; enforce driver-configured maximum detour threshold (e.g. max +15 min detour).
  - **User Stories**: US-208
  - **Target Files**: `lib/services/route_optimizer_service.dart`, `lib/screens/schedule_screen.dart`
  - **Test Target**: `test/route_optimizer_service_test.dart`

- [ ] **Automated Seat Allocation Rules & Objective Capping (US-209)**
  - **Details**: Implement automated priority rules (first-come, proximity order) for seat assignments; close passenger signups automatically when limits are reached with objective feedback.
  - **User Stories**: US-209
  - **Target Files**: `lib/screens/schedule_screen.dart`, `lib/models/models.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [ ] **Driver License, Insurance & Liability Attestation (US-210)**
  - **Details**: Secure profile storage for driver license and active insurance attestation; prompt drivers for annual organization liability confirmation prior to volunteering.
  - **User Stories**: US-210
  - **Target Files**: `lib/models/models.dart`, `lib/screens/settings_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [ ] **Booster Seat & Safety Equipment Verification (US-211)**
  - **Details**: Match child safety seat requirements (booster/rear-facing) against vehicle equipment capabilities specified by the driver before approving signups.
  - **User Stories**: US-211
  - **Target Files**: `lib/screens/schedule_screen.dart`, `lib/models/models.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [ ] **Pickup & Drop-off Handoff Verification (US-212)**
  - **Details**: adult check-in / pin-verify mechanism for child handoffs at pickup and destination delivery acknowledgment.
  - **User Stories**: US-212
  - **Target Files**: `lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`
  - **Test Target**: `test/user_stories_test.dart`

- [ ] **Emergency Route Handoff & Segment Transfer Protocol (US-213)**
  - **Details**: Transfer active or upcoming route segments between verified circle drivers during vehicle breakdown or emergency re-routing.
  - **User Stories**: US-213
  - **Target Files**: `lib/services/matrix_service.dart`, `lib/screens/active_route_screen.dart`
  - **Test Target**: `test/user_stories_test.dart`

---

## 🧪 Summary of Automated Test Suite

| Test File | Covered Functionality | Test Count / Status |
| :--- | :--- | :--- |
| `test/database_service_test.dart` | SQLite schema, tables, CRUD, cascading deletes, offline queueing, logout cleanup | **Passed** |
| `test/ical_parser_service_test.dart` | RFC 5545 feed parsing, VEVENT extraction, recurrence expansion | **Passed** |
| `test/route_optimizer_service_test.dart` | Haversine distance, greedy TSP solver, departure ETA offset calculation | **Passed** |
| `test/matrix_service_test.dart` | Discovery, authentication, sync loop, device keys, delay alerts, custom events | **Passed** |
| `test/user_stories_test.dart` | Comprehensive coverage for US-101 through US-404, dual-role scenarios C-1–C-5 | **Passed** |
| `test/widgets_test.dart` | Material 3 widgets (`EmptyStateWidget`, `OnboardingScreen`) | **Passed** |
| `test/app_info_test.dart` | Compile-time `--dart-define` metadata & `AboutAppDialog` rendering | **Passed** |
