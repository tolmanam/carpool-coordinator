# User Stories & Application Requirements

This document captures the complete set of user stories, personas, and system requirements for the **Carpool Coordinator** application.

---

## 👥 Personas

1. **Parent / Family Admin**: Manages family profile (supports families as small as a single adult), member profiles, home coordinates, and connects family members to organizations and carpool circles.
2. **Individual / Family Member**: An individual household member with customizable profile attributes (adult status, driving capability, optional Matrix ID, email, phone, avatar, emergency contact).
3. **Driver**: Adult family member who registers to drive specific activity commute occurrences, views optimized pickup routes, streams live location and status updates during active drives.
4. **Organization / Activity Coordinator**: Coach, teacher, or community leader who creates Organizations with shared schedules (iCal feeds) and manages Matrix Spaces tagged with Carpool Coordinator metadata.
5. **Generic Mobile User**: A first-time or returning app user managing authentication, notification settings, theme preferences, group chat, and offline data sync.

---

## 📖 User Stories

### Persona: Parent / Family Admin & Individual Profiles
- **US-101 (Profile Management)**: As a Family Admin, I want to create and customize my family profile (family name, home address, geographic coordinates) so that my household can participate in local carpool routes.
- **US-102 (Family Members & Profiles)**: As a Family Admin, I want to manage individual family members (adults, children, driving capability, optional email, phone, avatar, emergency contact, and private Matrix ID) so that members can be assigned to organizations and drives.
- **US-103 (Organization & Circle Joining)**: As a Family Admin, I want to join an Organization and create or join Carpool Circles (as subdivisions under an Organization) using email invites or space links.
- **US-104 (Organization Participant Assignment)**: As a Family Admin, I want to designate specific individual family members as Participants for an Organization (e.g., assigning a specific child to gymnastics or an adult to a bowling club).
- **US-105 (Ride Registration & Cancellation)**: As a Family Admin, I want to register or cancel a participant for an upcoming activity drive so that assigned drivers know who needs a ride.

### Persona: Driver
- **US-201 (Drive Sign-up)**: As a Driver, I want to volunteer to drive a specific event occurrence on the schedule so that the group has an assigned driver.
- **US-202 (Route Optimization)**: As a Driver, I want to view a Traveling Salesperson Problem (TSP) optimized pickup route and departure schedule based on registered passenger homes and the target destination.
- **US-203 (Active Drive & Live Tracking)**: As a Driver, I want to initiate an "Active Drive" mode that streams my real-time GPS position to passenger families at scheduled intervals.
- **US-204 (Delay Alerts)**: As a Driver, I want to trigger a delay alert (e.g. 5–10 min delay) that immediately notifies passenger parents via Matrix alerts.
- **US-205 (Driver Replacement / Drive Change)**: As a Driver, I want to unassign or replace myself from a scheduled drive if an emergency arises, allowing another parent to step in and take over driving duties.

### Persona: Organization / Activity Coordinator
- **US-301 (Organization & Schedule Setup)**: As an Activity Coordinator, I want to create an Organization with a Matrix Space (`m.space` tagged with Carpool Coordinator properties) and attach an iCalendar (`.ics`) feed URL so all member circles share the team schedule.
- **US-302 (Subdivision into Carpool Circles)**: As an Activity Coordinator or Parent, I want to subdivide an Organization into smaller, overlapping Carpool Circles where families coordinate specific pickup/dropoff responsibilities.
- **US-303 (Schedule Overrides)**: As an Activity Coordinator, I want to push schedule changes or event cancelations via calendar updates so that all member devices update their local offline schedules automatically.

### Persona: Generic Mobile User & Group Messaging
- **US-401 (Matrix Authentication & SSO)**: As a generic user, I want to log in using my Matrix homeserver credentials so that I don't need a separate app-specific backend account.
- **US-402 (Group Chat & Messaging)**: As a generic user, I want to participate in basic group chat rooms for my Family, Organizations, and Carpool Circles without enabling direct 1-on-1 messaging between individuals.
- **US-403 (Offline First Operation)**: As a generic user, I want full offline access to view schedules, routes, organization circles, and family details even when I have no active internet connection.
- **US-404 (Theme & Notification Customization)**: As a generic user, I want to customize application theme settings (Light Mode, Dark Mode, System Default) and notification alert sounds.

---

## 🛠️ Architectural & System Requirements

1. **Decentralized Matrix Paradigm**: Zero custom cloud backend servers. Shared group states, profiles, and sign-ups are stored in encrypted Matrix rooms (`m.room.state` and custom `org.carpool.*` payload messages).
2. **Local Persistence**: Uses local SQLite database for instant, offline-first data caching and optimistic UI updates.
3. **Client-Side Route Engine**: Runs Haversine distance-based Traveling Salesperson Problem (TSP) waypoint optimization directly on the driver's device.
4. **End-to-End Encryption (E2EE)**: End-to-end Megolm room encryption for child names, family addresses, coordinates, and schedules.
5. **Responsive Mobile Interface**: Responsive UI targeting Android mobile devices with Material Design components, clear empty states, and intuitive navigation.
