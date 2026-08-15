# Application Configuration Architecture & Material Design Template System

This document describes the application configuration settings, system options, profile management, family group configuration, carpool group administration, and the Material Design 3 template architecture in Carpool Coordinator.

---

## Material Design 3 Architecture

The application UI utilizes **React Native Paper** (`react-native-paper`) as the UI template engine for a professional Material Design experience across Android and iOS devices.

* **Root Provider (`app/_layout.tsx`)**: Wraps application screens in `PaperProvider` with a customized `MD3LightTheme` palette matching the brand theme (`#1d4ed8` primary blue, `#0284c7` secondary blue, `#10b981` tertiary green).
* **Material Components**:
  * `Card` & `Card.Content` for structured information presentation in schedules, circles, settings, and active routes.
  * `TextInput` with Material outlined borders and left icons (`server`, `account`, `lock`, `email-plus`, `home-heart`, etc.).
  * `Button` with filled, outlined, and contained-tonal variants and vector icons.
  * `Chip` for interactive filter states, role selections, and sign-up toggles.
  * `SegmentedButtons` for single-choice system toggles (Notification Sounds, Light/Dark/System themes).
  * `Banner` and `Surface` for offline sync indicators, active tracking alerts, and status elevation.

---

## 1. System Configuration

System configuration options govern core application behavior and connection settings. They are managed locally and stored in the SQLite `local_settings` key-value table.

### Matrix URL & Login (Re-authentication)
- **Settings Keys**: `homeserver`, `username`, `is_logged_in`
- **Behavior**:
  - Updating Matrix connection details (username or homeserver URL) triggers a immediate re-authentication flow (`reauthenticateAndClearCache`).
  - Upon re-authenticating, all cached SQLite data tables (`cached_families`, `cached_family_members`, `cached_schedules`, `local_ical_events`, `cached_signups`, `cached_routes`) are wiped to prevent cross-account data leaking.
  - User preferences (e.g. Dark Mode preference and Notification Sound) are preserved across re-login events.
  - Profile state and family data are immediately re-fetched and restored from Matrix rooms.

### Notification Sound
- **Settings Key**: `notification_sound`
- **Values**: Preset string (e.g., `'default'`, `'chime'`, `'bell'`, `'mute'`) or custom file/URL path string.
- **Behavior**: Persisted locally in SQLite `local_settings`. Used when triggering local trip alerts and delay notifications.

### Dark Mode / Theme Selection
- **Settings Key**: `theme_mode`
- **Values**: `'light' | 'dark' | 'system'`
- **Behavior**: Toggles application appearance settings locally across screens.

---

## 2. Profile Configuration

Profile settings configure user roles and personal identity within the decentralized network.

### Multi-Select Roles
- **Available Roles**:
  - `Parent`: Enables creation and ownership management of Carpool Groups.
  - `Driver`: Marks the user as eligible for route assignment and driver scheduling.
  - `Participant`: Indicates participation in carpool pickup/drop-off schedules.
- **Matrix State Event Synchronization**:
  - When profile roles are updated, a state event (`org.carpool.family.profile`) is broadcasted to Matrix rooms so that the user's role array is synchronized and visible across the family and carpool groups in real time.
  - Roles are stored locally as JSON arrays/strings in SQLite (`cached_family_members.role`).

---

## 3. Family Group Configuration

Family group configuration allows family managers (Parents) to organize family details and manage household members.

### Family Name & Members
- **Family Name**: Editable by parent users; updated in SQLite `cached_families` and broadcasted via `org.carpool.family.profile` state event.
- **Member Management**:
  - Parents can invite users (`@username:homeserver.org`) and add family members (e.g., children, spouse/co-parent).
  - Multi-select roles (`Parent`, `Driver`, `Participant` / `Child`) can be assigned per member.
  - Member modifications are saved locally and synchronized across the federated Matrix network.

---

## 4. Carpool Group Configuration

Carpool Groups (Schedules / Circles) facilitate shared transportation coordination between multiple families.

### Group Creation & Owner Permissions
- **Creation Restricted to Parents**: Only users with the `Parent` role assigned in their profile are allowed to create new Carpool Groups.
- **Ownership**: The creating parent is designated as the `owner_id` for the group.

### Multiple Event Sources (iCal Feeds)
- **Event Sources**: Carpool groups support configuring multiple external calendar event sources (`.ics` iCal feed URLs).
- **Manager Permissions**: Only the group owner/manager can add, edit, or remove iCal feed URLs for a group.
- **Synchronization**: Distributed sync parses events from all configured event sources to construct unified event occurrences.

### Family Group Participants & Membership
- **Family Invitations**: Group owners can invite other families (`@matrix_id`) to join the Carpool Group.
- **Role Assignment**: Owners can set/update family roles within the group.
- **Member Removal**:
  - Group owners can remove families from the carpool group.
  - Participating families may remove themselves from a group at any time.

---

## Summary Table

| Category | Option | Stored In | Matrix Sync Event | Permission Requirement |
| :--- | :--- | :--- | :--- | :--- |
| **System** | Matrix URL & Login | `local_settings` | Account Login | Any logged in user |
| **System** | Notification Sound | `local_settings` | N/A (Local) | Any logged in user |
| **System** | Dark Mode | `local_settings` | N/A (Local) | Any logged in user |
| **Profile** | Multi-Select Roles | `cached_family_members` | `org.carpool.family.profile` | Any logged in user |
| **Family Group** | Family Name & Members | `cached_families`, `cached_family_members` | `org.carpool.family.profile` | Parent role |
| **Carpool Group** | Group Creation | `cached_schedules` | `org.carpool.schedule` | Parent role |
| **Carpool Group** | Multiple Event Sources | `cached_schedules` | `org.carpool.schedule` | Group Owner |
| **Carpool Group** | Participant Management | `cached_families`, `cached_schedules` | `org.carpool.group.member` | Group Owner / Self |
