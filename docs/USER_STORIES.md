# User Stories & Application Requirements

This document captures the complete set of user stories, personas, combination role scenarios, gap analysis, and the system traceability matrix for the **Carpool Coordinator** application.

---

## 👥 Personas & Primary Roles

1. **Parent / Family Admin**: Manages family profile (supports single-adult households as well as multi-parent households), member profiles, home coordinates, and connects family members to organizations and carpool circles.
2. **Individual / Family Member**: An individual household member with customizable profile attributes (adult status, driving capability, optional Matrix ID, email, phone, avatar, emergency contact).
3. **Driver**: Adult family member who registers to drive specific activity commute occurrences, views optimized pickup routes, streams live location and status updates during active drives.
4. **Organization / Activity Coordinator**: Coach, teacher, or community leader who creates Organizations with shared schedules (iCal feeds) and manages Matrix Spaces tagged with Carpool Coordinator metadata.
5. **Generic Mobile User**: A first-time or returning app user managing authentication, notification settings, theme preferences, device verification keys, group chat, and offline data sync.

---

## 🔀 Dual-Role Combinations & Cross-Functional Scenarios

Real-world usage frequently requires users to act in multiple capacities simultaneously. The application supports the following key dual-role combination scenarios:

- **Scenario C-1: Parent Admin + Driver**
  - *Context*: A parent managing their family who also volunteers to drive for team practices.
  - *Behavior*: Accesses family profile management while having driver controls enabled on the Schedule tab. Can view generated TSP pickup routes and initiate Active Drive mode for their own registered child and other circle participants.
- **Scenario C-2: Activity Coordinator + Parent Admin**
  - *Context*: A soccer coach who is also a parent of one of the players on the team.
  - *Behavior*: Manages Organization Matrix Space setup and iCal feeds as Coordinator while registering their own child as a rider or themselves as a driver on specific occurrences.
- **Scenario C-3: Parent Admin Managing Multiple Children in Overlapping Circles**
  - *Context*: A parent with children in different age-group sports or school circles.
  - *Behavior*: Assigns specific children to different organizations/circles. The daily schedule aggregates events across all assigned circles without data leakage between unrelated carpool circles.
- **Scenario C-4: Single-Adult Household Admin**
  - *Context*: A single parent or adult living independently with a child.
  - *Behavior*: The family structure functions with a minimum of 1 adult. The single parent performs all family admin, driver volunteer, and ride registration actions.
- **Scenario C-5: Activity Coordinator + Driver**
  - *Context*: A league organizer or coach who steps in as driver when regular parent drivers are unavailable.
  - *Behavior*: Can edit schedule/iCal feeds as coordinator and switch seamlessly to drive activation and route optimization mode as driver.
- **Scenario C-6: Co-Parenting Multi-Household Scheduling**
  - *Context*: Separated parents sharing custody of a child in sports or school activities.
  - *Behavior*: Family Admin configures schedule-dependent pickup addresses (e.g. Household A on Mon/Wed, Household B on Tue/Thu), enabling TSP route generation to calculate waypoint coordinates dynamically based on the active custody schedule.
- **Scenario C-7: Delegated Helper / Babysitter Driver**
  - *Context*: A parent delegating ride driving or pickup duty to a grandparent or babysitter.
  - *Behavior*: Assigns temporary driver access to a trusted adult profile without exposing full family administration settings or financial/private data.

---

## 📖 User Stories

### Persona: Parent / Family Admin & Individual Profiles
- **US-101 (Profile Management)**: As a Family Admin, I want to create and customize my family profile (family name, home address, geographic coordinates) so that my household can participate in local carpool routes.
- **US-102 (Family Members & Profiles)**: As a Family Admin, I want to manage individual family members (adults, children, driving capability, optional email, phone, avatar, emergency contact, and private Matrix ID) so that members can be assigned to organizations and drives.
- **US-103 (Organization & Circle Joining)**: As a Family Admin, I want to join an Organization and create or join Carpool Circles (as subdivisions under an Organization) using email invites or space links.
- **US-104 (Organization Participant Assignment)**: As a Family Admin, I want to designate specific individual family members as Participants for an Organization (e.g., assigning a specific child to gymnastics or an adult to a bowling club).
- **US-105 (Ride Registration & Cancellation)**: As a Family Admin, I want to register or cancel a participant for an upcoming activity drive so that assigned drivers know who needs a ride.
- **US-106 (Child Without Matrix Account Handling)** *(Gap Story)*: As a Family Admin, I want my children without independent Matrix user accounts to be fully representable and scheduleable under my family umbrella account without requiring child credentials.
- **US-107 (Multi-Circle Participant Management)** *(Gap Story)*: As a Family Admin managing multiple children, I want to seamlessly map different family members to different organizations and circles without cross-circle participant clutter.
- **US-108 (Co-Parenting & Alternate Pickup Locations)** *(New Story)*: As a Family Admin in a joint custody arrangement, I want to specify alternating home addresses/coordinates per weekday or schedule occurrence so drivers pick up my child from the correct home location.
- **US-109 (Location Data Minimization & Privacy Controls)** *(New Story)*: As a Family Admin, I want my family's exact home address and coordinates shared only with the driver assigned to an active ride (and encrypted end-to-end), rather than exposed broadly to all room members.
- **US-110 (Child Safety, Booster Seat & Medical Notes)** *(New Story)*: As a Family Admin, I want to attach booster seat requirements and emergency medical/allergy notes to my child's profile so assigned drivers are automatically informed before starting a ride.
- **US-111 (Pickup & Drop-off Hand-off Verification)** *(New Story)*: As a Family Admin, I want real-time hand-off check-in confirmations (e.g. "Child Unloaded at Soccer Practice") so I know my child safely arrived at the destination.
- **US-112 (Delegated Driver & Temporary Helper Permissions)** *(New Story)*: As a Family Admin, I want to delegate driver or pickup privileges to a trusted helper (e.g. babysitter or grandparent) for specific rides without giving them full family admin rights.
- **US-113 (Schedule Conflict & Overlap Detection)** *(New Story)*: As a Family Admin, I want the application to highlight schedule overlaps across my children's assigned circles so I can proactively arrange rides for conflicting events.

### Persona: Driver
- **US-201 (Drive Sign-up)**: As a Driver, I want to volunteer to drive a specific event occurrence on the schedule so that the group has an assigned driver.
- **US-202 (Route Optimization)**: As a Driver, I want to view a Traveling Salesperson Problem (TSP) optimized pickup route and departure schedule based on registered passenger homes and the target destination.
- **US-203 (Active Drive & Live Tracking)**: As a Driver, I want to initiate an "Active Drive" mode that streams my real-time GPS position to passenger families at scheduled intervals.
- **US-204 (Delay Alerts)**: As a Driver, I want to trigger a delay alert (e.g. 5–10 min delay) that immediately notifies passenger parents via Matrix alerts.
- **US-205 (Driver Replacement / Drive Change)**: As a Driver, I want to unassign or replace myself from a scheduled drive if an emergency arises, allowing another parent to step in and take over driving duties.
- **US-206 (Driver Capacity & Vehicle Seat Limits)** *(Gap Story)*: As a Driver, I want to specify my vehicle's seat capacity when volunteering so that sign-ups cap automatically when the vehicle is full.
- **US-207 (Offline Driver Delay Queueing)** *(Gap Story)*: As a Driver, I want my delay alerts and route location updates to queue locally when cellular connectivity is lost and broadcast immediately upon reconnecting.
- **US-208 (Route Impact Preview & Maximum Detour Thresholds)** *(Gap Story)*: As a Driver, I want to preview the additional detour time/distance for potential passenger pickups against a configurable maximum detour threshold (e.g., max +15 mins detour) before committing to drive, so I can gracefully manage my schedule and set clear social boundaries without awkward manual refusals.
- **US-209 (Seat Allocation Rules & Graceful Capping)** *(Gap Story)*: As a Driver, I want automated seat allocation rules (e.g., first-come-first-served, proximity order, or family preference) that automatically close passenger signups when seat/booster limits are reached, providing objective system-level feedback to parents when a car is full.
- **US-210 (Driver License, Insurance & Liability Attestation)** *(Gap Story)*: As a Driver, I want to log my driving credentials (valid license, active vehicle insurance attestation) within my private profile and confirm annual liability terms before volunteering, ensuring compliance with league/organization safety policies.
- **US-211 (Booster Seat & Child Safety Equipment Verification)** *(Gap Story)*: As a Driver, I want rider signups to explicitly indicate required child safety equipment (e.g., booster seat, rear-facing seat) so I can verify equipment compatibility and availability before accepting passenger assignments.
- **US-212 (Pickup & Drop-off Handoff Verification)** *(Gap Story)*: As a Driver, I want a secure handoff confirmation mechanism (e.g., adult check-in at pickup and destination adult handoff acknowledgment) to ensure child safety, prevent accidental drop-off errors, and provide real-time peace of mind to parents.
- **US-213 (Emergency Route Handoff & Segment Transfer)** *(Gap Story)*: As a Driver, I want to transfer an active or upcoming drive route (or specific pickup segments) to another verified circle driver in the event of a vehicle breakdown or personal emergency, seamlessly re-routing remaining passenger pickups.

### Persona: Organization / Activity Coordinator
- **US-301 (Organization & Schedule Setup)**: As an Activity Coordinator, I want to create an Organization with a Matrix Space (`m.space` tagged with Carpool Coordinator properties) and attach an iCalendar (`.ics`) feed URL so all member circles share the team schedule.
- **US-302 (Subdivision into Carpool Circles)**: As an Activity Coordinator or Parent, I want to subdivide an Organization into smaller, overlapping Carpool Circles where families coordinate specific pickup/dropoff responsibilities.
- **US-303 (Schedule Overrides)**: As an Activity Coordinator, I want to push schedule changes or event cancelations via calendar updates so that all member devices update their local offline schedules automatically.
- **US-304 (iCal Feed Sync Conflict Resolution)** *(Gap Story)*: As an Activity Coordinator, I want a distributed lock protocol (`org.carpool.ical_lock`) to prevent redundant or conflicting Matrix iCal synchronization requests across devices.
- **US-305 (Organization Room Moderation & Admin Delegation)** *(Gap Story)*: As an Activity Coordinator, I want to delegate circle moderation or admin roles to other parents in the Matrix Space.
- **US-306 (Member Self-Service Onboarding & Offboarding)** *(New Coordinator Story)*: As an Activity Coordinator, I want members to join via QR codes or invite links and manage/delete their own family profiles, eliminating manual entry burden on the organizer.
- **US-307 (Dynamic Privacy & Selective Location Disclosure)** *(New Coordinator Story)*: As an Activity Coordinator, I want home addresses and GPS coordinates to be visible strictly to designated drivers during active commute windows, ensuring sensitive family location data remains private from general group members.
- **US-308 (Equipment & Seat Logistics Requirements)** *(New Coordinator Story)*: As an Activity Coordinator, I want parents to specify special equipment needs (e.g. sports gear, musical instruments) or seating equipment (e.g. booster seats) so drivers can ensure adequate vehicle space.
- **US-309 (Multi-Calendar Feed & Custom Event Announcements)** *(New Coordinator Story)*: As an Activity Coordinator, I want to attach multiple iCal feeds per Organization and broadcast direct custom Matrix schedule announcements, keeping all member circles synchronized.
- **US-310 (Dynamic Emergency Contact & Medical Notes Access)** *(New Coordinator Story)*: As an Activity Coordinator, I want emergency contacts and medical/allergy notes to be accessible exclusively to assigned drivers during active drives, balancing emergency safety with strict privacy.
- **US-311 (Urgent Cancellation & Weather Delay Broadcast)** *(New Coordinator Story)*: As an Activity Coordinator, I want to broadcast urgent alert events across the Matrix space for sudden schedule cancellations or weather delays, immediately updating all member views.
- **US-312 (Attendance Tracking & Commute Headcount Verification)** *(New Coordinator Story)*: As an Activity Coordinator or Driver, I want drivers to record participant pickup and drop-off check-ins during active routes so that parents and coordinators have real-time headcount verification.
- **US-313 (Organization Role Transfer & Delegated Moderation)** *(New Coordinator Story)*: As an Activity Coordinator, I want to delegate co-coordinator permissions or transfer organization space ownership using Matrix room power levels, enabling smooth leadership transitions without cloud backend intervention.

### Persona: Generic Mobile User & Group Messaging
- **US-401 (Matrix Authentication & SSO)**: As a generic user, I want to log in using my Matrix homeserver credentials so that I don't need a separate app-specific backend account.
- **US-402 (Group Chat & Messaging)**: As a generic user, I want to participate in basic group chat rooms for my Family, Organizations, and Carpool Circles without enabling direct 1-on-1 messaging between individuals.
- **US-403 (Offline First Operation)**: As a generic user, I want full offline access to view schedules, routes, organization circles, and family details even when I have no active internet connection.
- **US-404 (Theme & Notification Customization)**: As a generic user, I want to customize application theme settings (Light Mode, Dark Mode, System Default) and notification alert sounds.
- **US-405 (Matrix Device Key Verification)** *(Gap Story)*: As a generic user, I want to inspect and manage device verification keys for my Matrix account to ensure secure E2EE communication across devices.
- **US-406 (Local Encrypted Data Cleanup & Reset)** *(Gap Story)*: As a generic user, I want to clear cached SQLite database contents or reset my local profile on logout.

---

## 📊 Comprehensive Traceability, Coverage & Gap Matrix

The table below provides a complete audit of every User Story and Dual-Role Scenario, detailing its current implementation state, automated test coverage, documentation status, and remaining gap analysis.

| Story / Scenario ID | User Role / Persona | Summary / Feature Focus | Implementation Status | Automated Test Coverage | Documentation Status | Gap Analysis & Next Steps |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **US-101** | Parent Admin | Family profile creation & address coordinates | **Implemented** (`lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`, `test/database_service_test.dart`) | **Documented** | Fully implemented with local SQLite persistence and model mapping. |
| **US-102** | Parent Admin | Family member creation, adult/child role, driving flag, Matrix ID | **Implemented** (`lib/models/models.dart`, `lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`, `test/database_service_test.dart`) | **Documented** | Fully supported in SQLite schema; optional member Matrix ID supported. |
| **US-103** | Parent Admin | Join Organization and create/join Carpool Circles | **Implemented** (`lib/screens/circles_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Supports Matrix spaces, room creation, and email/mailto invite links. |
| **US-104** | Parent Admin | Assign specific family members as Organization participants | **Implemented** (`lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Fully functional via `OrganizationParticipant` SQLite table. |
| **US-105** | Parent Admin | Register/cancel participant rides for schedule occurrences | **Implemented** (`lib/screens/schedule_screen.dart`, `lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Supports ride signup creation and opt-out deletion in SQLite/Matrix state. |
| **US-106** *(New)* | Parent Admin | Handle children without Matrix IDs under family umbrella | **Implemented** (`lib/models/models.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | `FamilyMember` allows empty `memberMatrixId`; child linked by `family_id`. |
| **US-107** *(New)* | Parent Admin | Multi-circle participant filtering per child | **Implemented** (`lib/services/database_service.dart`) | **Passed** (`test/database_service_test.dart`) | **Documented** | `circle_id` filtering in `OrganizationParticipant` model separates circle rosters. |
| **US-108** *(New)* | Parent Admin | Co-Parenting alternate pickup locations & schedules | **Documented** | Pending | **Documented** | Planned data model extension for per-day home address coordinates in TSP route generation. |
| **US-109** *(New)* | Parent Admin | Location data minimization & driver-only E2EE sharing | **Documented** | Pending | **Documented** | Planned ephemeral Olm/Megolm key exchange restricting address exposure to assigned driver. |
| **US-110** *(New)* | Parent Admin | Child booster seat & medical safety notes | **Documented** | Pending | **Documented** | Planned safety flags on `FamilyMember` displayed during active drives. |
| **US-111** *(New)* | Parent Admin | Pickup & drop-off hand-off check-in verification | **Documented** | Pending | **Documented** | Planned Matrix room state event triggers for child arrival/departure confirmations. |
| **US-112** *(New)* | Parent Admin | Delegated helper & temporary driver permissions | **Documented** | Pending | **Documented** | Planned scoped temporary driver token/role without granting family admin rights. |
| **US-113** *(New)* | Parent Admin | Schedule overlap & conflict detection | **Documented** | Pending | **Documented** | Planned conflict visualizer in iCal engine for multi-child overlapping events. |
| **US-201** | Driver | Volunteer to drive specific event occurrence | **Implemented** (`lib/screens/schedule_screen.dart`, `lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Driver signups store role `'driver'` and broadcast custom Matrix event. |
| **US-202** | Driver | TSP optimized pickup route calculation & ETAs | **Implemented** (`lib/services/route_optimizer_service.dart`, `lib/screens/active_route_screen.dart`) | **Passed** (`test/route_optimizer_service_test.dart`) | **Documented** | Greedy TSP solver with Haversine distance formula implemented and tested. |
| **US-203** | Driver | Active drive mode & GPS position streaming | **Implemented** (`lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/matrix_service_test.dart`) | **Documented** | Real-time simulation & position payload messaging to Matrix rooms. |
| **US-204** | Driver | Trigger delay alerts (5-10 min) to Matrix room | **Implemented** (`lib/screens/active_route_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/matrix_service_test.dart`) | **Documented** | Sends `org.carpool.alert` room payload with delay duration and notes. |
| **US-205** | Driver | Driver replacement & drive unassignment | **Implemented** (`lib/screens/schedule_screen.dart`, `lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Driver cancellation removes signup, enabling another driver to sign up. |
| **US-206** *(New)* | Driver | Vehicle seat capacity limits on drive signups | **Implemented** (`lib/models/models.dart`, `lib/screens/schedule_screen.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | `seat_capacity` supported in Signup model/SQLite schema; capacity limits enforced in Schedule UI. |
| **US-207** *(New)* | Driver | Offline queueing of driver delay alerts | **Implemented** (`lib/services/matrix_service.dart`, `lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Driver delay alerts and location updates queue in local SQLite table and flush automatically upon reconnection/sync. |
| **US-208** *(New)* | Driver | Route impact preview & max detour thresholds | **Planned** | **Pending** | **Documented** | Max detour threshold setting and pre-drive TSP delta calculation to manage driver schedule boundaries. |
| **US-209** *(New)* | Driver | Automated seat allocation rules & capping | **Planned** | **Pending** | **Documented** | Priority allocation rules (proximity/first-come) and objective seat cap enforcement. |
| **US-210** *(New)* | Driver | Driver license, insurance & liability attestation | **Planned** | **Pending** | **Documented** | Encrypted driver credential storage and organization policy liability attestation. |
| **US-211** *(New)* | Driver | Booster seat & safety equipment verification | **Planned** | **Pending** | **Documented** | Rider equipment metadata matching against vehicle seat capabilities. |
| **US-212** *(New)* | Driver | Pickup & drop-off child handoff verification | **Planned** | **Pending** | **Documented** | QR/PIN or tap-to-verify handoff status updates for pickup and destination delivery. |
| **US-213** *(New)* | Driver | Emergency route handoff & segment transfer | **Planned** | **Pending** | **Documented** | Route re-assignment and passenger segment transfer protocol between drivers during emergencies. |
| **US-301** | Activity Coordinator | Organization creation with Matrix Space & iCal feed | **Implemented** (`lib/services/matrix_service.dart`, `lib/services/ical_parser_service.dart`) | **Passed** (`test/user_stories_test.dart`, `test/ical_parser_service_test.dart`) | **Documented** | Creates Matrix Space and parses RFC 5545 iCal strings into database. |
| **US-302** | Activity Coordinator | Subdivide Organization into Carpool Circles | **Implemented** (`lib/services/matrix_service.dart`, `lib/screens/circles_screen.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Creates child rooms (`m.space.child`) under Organization space. |
| **US-303** | Activity Coordinator | Schedule overrides & offline calendar updates | **Implemented** (`lib/services/ical_parser_service.dart`) | **Passed** (`test/ical_parser_service_test.dart`) | **Documented** | Re-parsing updated iCal feeds updates offline local event occurrences. |
| **US-304** *(New)* | Activity Coordinator | iCal sync distributed lock protocol | **Implemented** (`lib/services/matrix_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | `org.carpool.ical_lock` state protocol check and recording loosely coordinates distributed device iCal updates. |
| **US-305** *(New)* | Activity Coordinator | Matrix Space moderation & admin delegation | **Implemented** (`lib/services/matrix_service.dart`) | **Passed** (`test/matrix_service_test.dart`) | **Documented** | Room power levels editable via Matrix API (`/state/m.room.power_levels`). |
| **US-306** *(New)* | Activity Coordinator | Self-service onboarding (QR/link) & data offboarding | **Documented / Spec** | **Planned** | **Documented** | Members join via `matrix.to` space links/QR codes; self-service data management via encrypted state events. |
| **US-307** *(New)* | Activity Coordinator | Selective location disclosure to active drivers | **Documented / Spec** | **Planned** | **Documented** | Address coordinates encrypted; decrypted only by driver assigned to active commute session. |
| **US-308** *(New)* | Activity Coordinator | Equipment (gear bags/instruments) & booster seat tagging | **Documented / Spec** | **Planned** | **Documented** | `org.carpool.equipment` state event tags gear volume & booster seat counts on signups. |
| **US-309** *(New)* | Activity Coordinator | Multi-iCal feeds & direct Matrix event announcements | **Documented / Spec** | **Planned** | **Documented** | `org.carpool.schedule_announcement` events supplement external iCal URLs for ad-hoc events. |
| **US-310** *(New)* | Activity Coordinator | Dynamic emergency contact & medical note access | **Documented / Spec** | **Planned** | **Documented** | Temporary key release or role-based active drive state disclosure for medical/emergency info. |
| **US-311** *(New)* | Activity Coordinator | High-priority urgent cancellation & weather broadcast | **Documented / Spec** | **Planned** | **Documented** | `org.carpool.urgent_alert` high-priority event dispatches push updates across space members. |
| **US-312** *(New)* | Activity Coordinator | Attendance tracking & participant pickup verification | **Documented / Spec** | **Planned** | **Documented** | `org.carpool.checkin` state updates record pickup/drop-off timestamps per participant. |
| **US-313** *(New)* | Activity Coordinator | Organization leadership transfer & co-moderator delegation | **Documented / Spec** | **Planned** | **Documented** | Native Matrix `m.room.power_levels` state updates enable zero-backend ownership transfer. |
| **US-401** | Generic Mobile User | Matrix authentication & federated SSO login | **Implemented** (`lib/screens/login_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Direct Matrix REST login (`/_matrix/client/v3/login`) with custom homeserver support. |
| **US-402** | Generic Mobile User | Group chat in Family, Org, and Circle rooms | **Implemented** (`lib/screens/circles_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Send and view room chat messages using `m.room.message` events. |
| **US-403** | Generic Mobile User | Offline-first schedule, route, & profile viewing | **Implemented** (`lib/services/database_service.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Full SQLite caching enables instant offline reads across all screens. |
| **US-404** | Generic Mobile User | Application theme (Light/Dark) & notifications | **Implemented** (`lib/screens/settings_screen.dart`, `lib/main.dart`) | **Passed** (`test/user_stories_test.dart`) | **Documented** | Dynamic Material 3 light/dark theme switching via settings provider. |
| **US-405** *(New)* | Generic Mobile User | Matrix device verification key management | **Implemented** (`lib/screens/settings_screen.dart`, `lib/services/matrix_service.dart`) | **Passed** (`test/matrix_service_test.dart`) | **Documented** | Device listing, key query, and verification status toggling implemented in UI/service. |
| **US-406** *(New)* | Generic Mobile User | Local encrypted database cleanup on logout | **Implemented** (`lib/services/database_service.dart`) | **Passed** (`test/database_service_test.dart`) | **Documented** | Invokes database table purge and SharedPreferences reset upon user logout. |
| **Scenario C-1** | Parent + Driver | Single user managing family & driving carpool | **Implemented** | **Passed** (`test/user_stories_test.dart`) | **Documented** | UI tabs enable seamless switching between family profile and active driving. |
| **Scenario C-2** | Coordinator + Parent | Coach organizing space & registering own child | **Implemented** | **Passed** (`test/user_stories_test.dart`) | **Documented** | Space admin can assign family members as participants in created circles. |
| **Scenario C-3** | Parent w/ Multi-Kids | Managing children in separate overlapping circles | **Implemented** | **Passed** (`test/database_service_test.dart`) | **Documented** | Roster filters show distinct children in gymnastics vs. soccer circles. |
| **Scenario C-4** | Single-Adult Household | Single parent admin managing family unit | **Implemented** | **Passed** (`test/database_service_test.dart`) | **Documented** | Minimum family unit requirement set to 1 adult in schema and business logic. |
| **Scenario C-5** | Coordinator + Driver | Activity coordinator taking over drive | **Implemented** | **Passed** (`test/user_stories_test.dart`) | **Documented** | Space admin can register as driver on any scheduled circle occurrence. |
| **Scenario C-6** *(New)* | Co-Parenting Admin | Dual household custody schedule & location handling | **Documented** | Pending | **Documented** | Planned support for alternating day-of-week household pickup coordinates in TSP solver. |
| **Scenario C-7** *(New)* | Parent + Helper | Delegated babysitter / grandparent driver permissions | **Documented** | Pending | **Documented** | Planned scoped temporary driver access without family admin configuration rights. |

---

## 🛠️ Architectural & System Requirements

1. **Decentralized Matrix Paradigm**: Zero custom cloud backend servers. Shared group states, profiles, and sign-ups are stored in encrypted Matrix rooms (`m.room.state` and custom `org.carpool.*` payload messages).
2. **Local Persistence**: Uses local SQLite database (`sqflite`) for instant, offline-first data caching and optimistic UI updates.
3. **Client-Side Route Engine**: Runs Haversine distance-based Traveling Salesperson Problem (TSP) waypoint optimization directly on the driver's device.
4. **End-to-End Encryption (E2EE)**: End-to-end Megolm room encryption for child names, family addresses, coordinates, and schedules.
5. **Responsive Mobile Interface**: Responsive UI targeting Android mobile devices with Material Design 3 components, clear empty states, and intuitive navigation.
