# User Stories & Application Requirements

This document captures the core user stories, personas, and requirements for the **Carpool Coordinator** application.

---

## Organizations

1. **Individual**: Human participants that log into the app.  Each human may be associated with zero or one Matrix account.  Young "passengers" don't require their own Matrix account, but the option is there so that older kids can use the app to see the plan and communicate
3. **Family/Group**: Self organized group of **individuals**.
4. **Carpool Circle**: Carpool circles group **passengers** with specific schedules.  

## 👥 Individual Personas/Roles

1. **Parent / Family Admin**: Manages family profile, members, home location, and connects carpool circles/groups.
2. **Driver**: Registers to drive specific commutes, views calculated optimal pickup routes/ETAs, streams live GPS updates, and dispatches delay alerts.
3. **Passenger / Child**: Listed on schedules to be picked up and dropped off at activities.

---

## 📖 User Stories

*(User stories will be added and expanded here during iteration)*
### Persona: All
- **US-001**: As an Individual, when I open the app the first time, I should be greeted by a Matrix login screen.
- **US-002**: As an Individual, after logging in, the application should provide a list of Carpool Circles that the user is a member of.
- **US-003**: As an Individual, I should be able to accept invitations to join Family/Groups and Carpool Circles

### Persona: Parent / Family Admin
- **US-101**: As a Parent, I want to create and customize my family profile with members (using a Matrix room) and home coordinates so that my household can join carpool groups.
- **US-102**: As a Parent, I want to create or join a Carpool Circle (using a Matrix room) so that I can coordinate commutes with other families privately.

### Persona: Driver
- **US-201**: As a Driver, I want to sign up to drive specific activity occurrences on the schedule so that passengers know who is driving.
- **US-202**: As a Driver, I want to view an optimized pickup route and departure schedule so that I can pick up all riders efficiently.
- **US-203**: As a Driver, I want to start an active drive that streams location updates and alerts passengers if I am delayed.

### Persona: Passenger Parent / Rider
- **US-301**: As a Passenger Parent, I want to register my child for upcoming carpool rides so that a driver can pick them up.
- **US-302**: As a Passenger Parent, I want to view live ETAs and driver tracking during an active commute so that I know when my child will be picked up or dropped off.

---

## 🛠️ System & Non-Functional Requirements

1. **Decentralized Storage**: Operates entirely via Matrix rooms without custom backend servers.
2. **Offline First**: Full offline schedule viewing and local state caching using SQLite.
3. **Privacy & Security**: End-to-end encryption for all personal details, member names, and location coordinates.
4. **Android Native Performance**: Responsive Material 3 / Material Design UI with native performance and clear empty state feedback.
