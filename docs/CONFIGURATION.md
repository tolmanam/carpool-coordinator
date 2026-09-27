# Application Configuration Architecture & Material Design 3 System

This document describes the application configuration settings, system options, profile management, family group configuration, carpool group administration, and the Material Design 3 architecture in Carpool Coordinator.

---

## Material Design 3 Architecture

The application UI utilizes Flutter **Material Design 3** (`useMaterial3: true`) for a clean, consistent user experience across Android, iOS, Desktop, and Web.

* **Root Configuration (`lib/main.dart`)**: Wraps application screens in `MaterialApp` configured with custom `ThemeData` (`useMaterial3: true`) matching the brand theme (`#1d4ed8` primary blue, `#0284c7` secondary blue, `#10b981` tertiary green) with reactive light/dark theme switching powered by `SettingsProvider`.
* **Material 3 Components**:
  * `NavigationBar` for clean bottom tab navigation across Schedule, Circles, Active Route, and Settings screens.
  * `Card` & `ListTile` for structured information presentation in schedules, circles, and settings.
  * `TextField` with Material outlined borders and prefix icons (`dns`, `person`, `lock`, `email`, `home`, `phone`, etc.).
  * `ElevatedButton`, `OutlinedButton`, `TextButton`, and `FilledButton` with vector icons.
  * `Chip` & `ChoiceChip` for interactive filter states, role selections, and signup toggles.
  * `SegmentedButton` for single-choice system toggles (Notification Sounds, Light/Dark/System themes).
  * `EmptyStateWidget` for clear placeholders when lists are empty.

---

## 1. System Configuration

System configuration options govern core application behavior and Matrix connection settings. They are managed locally and stored in the SQLite `settings` key-value table via `DatabaseService`.

### Matrix URL & Login (Re-authentication)
- **Settings Keys**: `homeserver`, `username`, `matrix_access_token`, `matrix_user_id`, `matrix_device_id`
- **Behavior**:
  - Updating Matrix connection details or logging out clears cached SQLite database tables (`family_profiles`, `family_members`, `organizations`, `carpool_circles`, `organization_participants`, `schedules`, `local_ical_events`, `signups`, `route_waypoints`) to prevent cross-account data leaks.
  - User preferences (e.g., theme preference and notification sound) are preserved across re-login events.
  - Profile state and family data are immediately re-fetched and restored from Matrix rooms upon login.

### Notification Sound
- **Settings Key**: `notification_sound`
- **Values**: Preset string (e.g., `'default'`, `'chime'`, `'bell'`, `'mute'`) or custom alert file string.
- **Behavior**: Persisted locally in SQLite `settings` table. Used when triggering local trip alerts and delay notifications.

### Dark Mode / Theme Selection
- **Settings Key**: `theme_mode`
- **Values**: `'light' | 'dark' | 'system'`
- **Behavior**: Toggles application appearance settings locally across screens.

---

## 2. Profile Configuration

Profile settings configure user roles and personal identity within the decentralized network.

### Multi-Select Roles
- **Available Roles**:
  - `Parent / Family Admin`: Enables creation and management of family profiles, members, and carpool circles.
  - `Driver`: Marks an adult family member as eligible for route assignment and driver scheduling.
  - `Participant / Child`: Indicates participation in carpool pickup/dropoff schedules.
- **Matrix State Event Synchronization**:
  - When profile roles are updated, a state event (`org.carpool.family.profile`) is broadcasted to Matrix rooms so that the user's role array is synchronized and visible across family and carpool groups in real time.
  - Roles are stored locally in SQLite (`family_members.role`).

---

## 3. Family Group Configuration

Family group configuration allows family managers (Parents) to organize family details and manage household members.

### Family Name & Members
- **Family Name**: Editable by parent users; updated in SQLite `family_profiles` and broadcasted via `org.carpool.family.profile` state event.
- **Member Management**:
  - Parents can manage family members (adults, children, driving capability, email, phone, avatar, emergency contact, optional member Matrix ID).
  - Single-adult households are fully supported as a minimum valid family unit.
  - Member modifications are saved locally and synchronized across the federated Matrix network.

---

## 4. Carpool Group Configuration

Carpool Groups (Organizations / Carpool Circles) facilitate shared transportation coordination between multiple families.

### Group Creation & Space Hierarchy
- **Organizations (Spaces)**: Activity coordinators or parents create Matrix Spaces tagged with `org.carpool.organization: true` and attach an iCal feed URL.
- **Carpool Circles (Child Rooms)**: Subdivisions (`m.space.child`) under an Organization Space where specific pickup/dropoff responsibilities are coordinated.

### Multiple Event Sources (iCal Feeds)
- **Event Sources**: Organizations support configuring external calendar event sources (`.ics` iCal feed URLs).
- **Synchronization**: Client-side parsing in `IcalParserService` expands event rules into local event occurrences.

### Family Group Participants & Membership
- **Family Invitations**: Space owners can invite other families via `matrix.to` space links or email `mailto:` URIs populated with room links.
- **Participant Assignment**: Parents assign specific children to specific circles.

---

## Summary Table

| Category | Option | Stored In | Matrix Sync Event | Permission Requirement |
| :--- | :--- | :--- | :--- | :--- |
| **System** | Matrix URL & Login | `settings` | Account Login (`/_matrix/client/v3/login`) | Any logged in user |
| **System** | Notification Sound | `settings` | N/A (Local) | Any logged in user |
| **System** | Dark Mode | `settings` | N/A (Local) | Any logged in user |
| **Profile** | Multi-Select Roles | `family_members` | `org.carpool.family.profile` | Any logged in user |
| **Family Group** | Family Name & Members | `family_profiles`, `family_members` | `org.carpool.family.profile` | Parent role |
| **Carpool Group** | Group / Space Creation | `organizations`, `carpool_circles` | `m.space`, `org.carpool.organization` | Parent / Coordinator |
| **Carpool Group** | iCal Event Sources | `schedules` | `org.carpool.schedules` | Space Coordinator |
| **Carpool Group** | Participant Management | `organization_participants` | `org.carpool.signup` | Parent / Coordinator |
