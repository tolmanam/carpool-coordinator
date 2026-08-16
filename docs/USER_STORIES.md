# User Stories & Application Requirements

This document captures the complete set of user stories, personas, and system requirements for the **Carpool Coordinator** application (Flutter / Material 3 Edition).

---

## 👥 Personas

1. **Parent / Family Admin**: Manages family profile, member profiles (children/adults), home coordinates, and connects family members to carpool circles.
2. **Driver**: Parent or authorized guardian who registers to drive specific activity commute occurrences, views optimized pickup routes, streams live location during active drives, and reports delays.
3. **Passenger / Child**: Household member assigned to be picked up and dropped off for scheduled activities.
4. **Organization / Activity Coordinator**: Coach, teacher, or community leader who creates activity calendars (iCal feeds), manages Matrix coordination spaces/rooms, and shares schedule links with parents.
5. **Generic Mobile User**: A first-time or returning app user managing authentication, notification settings, theme preferences, and offline data sync.

---

## 📖 User Stories

### Persona: Parent / Family Admin
- **US-101 (Profile Management)**: As a Parent, I want to create and customize my family profile (family name, home address, geographic coordinates) so that my household can participate in local carpool routes.
- **US-102 (Family Members)**: As a Parent, I want to add family members (children, secondary guardians) with designated roles so that they can be assigned to rides or driving duties.
- **US-103 (Circle Joining)**: As a Parent, I want to create or join a Carpool Circle using a Matrix room invite so that I can coordinate rides securely with known families.
- **US-104 (Ride Registration)**: As a Parent, I want to register my child for an upcoming activity commute so that assigned drivers know who needs a ride.

### Persona: Driver
- **US-201 (Drive Sign-up)**: As a Driver, I want to volunteer to drive a specific event occurrence on the schedule so that the group has an assigned driver.
- **US-202 (Route Optimization)**: As a Driver, I want to view a Traveling Salesperson Problem (TSP) optimized pickup route and departure schedule based on registered passenger homes and the target destination.
- **US-203 (Active Drive & Live Tracking)**: As a Driver, I want to initiate an "Active Drive" mode that streams my real-time GPS position to passenger families at scheduled intervals.
- **US-204 (Delay Alerts)**: As a Driver, I want to trigger a delay alert (e.g. 5–10 min delay) that immediately notifies passenger parents via Matrix alerts.
- **US-205 (Driver Replacement)**: As a Driver, I want to unassign myself from a drive if an emergency arises, prompting the circle to notify available drivers.

### Persona: Organization / Activity Coordinator
- **US-301 (Calendar Feed Publishing)**: As an Activity Coordinator, I want to publish an iCalendar (`.ics`) feed URL for our club/school team so that parents can sync activity schedules automatically.
- **US-302 (Circle Creation)**: As an Activity Coordinator, I want to set up an official Matrix carpool room for our organization and distribute join links/QR codes to participating families.
- **US-303 (Schedule Overrides)**: As an Activity Coordinator, I want to push schedule changes or event cancelations via calendar updates so that all member devices update their local offline schedules automatically.

### Persona: Generic Mobile User
- **US-401 (Matrix Authentication & SSO)**: As a generic user, I want to log in using my Matrix homeserver credentials or OIDC / SSO single sign-on so that I don't need a separate app-specific backend account.
- **US-402 (First-Time Onboarding & Empty States)**: As a generic user launching the app for the first time, I want a clear, step-by-step onboarding walkthrough and helpful empty states when no circles or schedules are configured yet.
- **US-403 (Offline First Operation)**: As a generic user, I want full offline access to view schedules, routes, and family details even when I have no active internet connection.
- **US-404 (Theme & Notification Customization)**: As a generic user, I want to customize application theme settings (Light Mode, Dark Mode, System Default) and notification alert sounds.

---

## 🛠️ Architectural & System Requirements

1. **Flutter 3 / Material 3 Core**: Built using Flutter 3 (Dart) targeting Android devices, adhering to Material Design 3 guidelines (`useMaterial3: true`).
2. **Decentralized Matrix Paradigm**: Zero custom cloud backend servers. Shared group states, profiles, and sign-ups are stored in encrypted Matrix rooms (`m.room.state` and custom `org.carpool.*` payload messages).
3. **Local SQLite Persistence**: Uses local SQLite database (`drift` / `sqflite`) for instant, offline-first data caching and optimistic UI updates.
4. **Client-Side Route Engine**: Runs Haversine distance-based Traveling Salesperson Problem (TSP) waypoint optimization directly on the driver's device.
5. **End-to-End Encryption (E2EE)**: End-to-end Megolm room encryption for child names, family addresses, coordinates, and schedules.
