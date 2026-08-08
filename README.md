# Carpool Coordinator - Matrix Edition

An elegant, **fully decentralized, zero-cloud-cost**, offline-first solution for self-organized families, teams, and schools to coordinate carpooling, tracking, and schedules with absolute privacy using **Matrix**.

---

## 🚀 Key Advantages of the Matrix Paradigm

* **Zero Hosting Costs**: Eliminates backends, servers, and central databases. The application runs entirely on your phone (client-side), storing decentralized states and messages directly inside **Matrix rooms**.
* **Absolute Privacy**: Relies on Matrix's native **End-to-End Encryption (E2EE)** (Olm/Megolm) to encrypt children's names, home addresses, coordinates, and schedules, keeping them entirely invisible to homeserver admins.
* **No Separate Identity Provider**: Uses standard Matrix accounts (e.g., from matrix.org or self-hosted servers) for instant secure authentication.
* **Local-First & Offline Tolerant**: Clients function offline seamlessly using a local SQLite database, updating coordinates and schedules automatically when a network connection is resumed.

---

## 🛠️ Main Features

1. **Decentralized Matrix Authentication**
   * Instant sign-in using any standard Matrix homeserver credential.
2. **Local-First iCal parser**
   * Client-side iCalendar (`.ics`) loader fetches school or activity calendars, parsing them directly into your local offline index.
3. **Decentralized Group Management**
   * Uses E2EE Matrix Rooms to represent family groups. Room joins, invites, and profiles translate straight into family coordination circles.
4. **Client-Side Route Calculations**
   * Runs local Traveling Salesperson Problem (TSP) algorithms directly on the driver's phone to plan the fastest pickup route and generate scheduled pickup ETAs.
5. **Real-Time Tracking & Alerts**
   * Streams ephemeral GPS positions directly into Matrix rooms during active carpools, calculating dynamic arrival times and dispatching immediate room alerts (sickness, cancellation, delays).

---

## 📁 Project Structure

* `/docs/architecture.md` - Technical Architecture, Decentralization philosophy, and Privacy controls.
* `/docs/database.md` - Custom Matrix Event specifications & local SQLite database tables.
* `/docs/api.md` - Client-side Matrix room setup flows, iCal parsers, and TSP route calculation flows.

---

## 🗺️ Roadmap

- [ ] **Phase 1: Local-First Core**
  - Setup React Native / Expo with `expo-sqlite` and local iCal RFC 5545 parser.
- [ ] **Phase 2: Matrix Integration**
  - Integrate native Matrix SDK, implementing private room setups, user invitations, and custom state event (`org.carpool.family.profile`, `org.carpool.schedules`) sync.
- [ ] **Phase 3: Route Optimizer & Scheduler**
  - Build local client-side route sequence solvers (such as `turf.js` or free Valhalla queries) to arrange pickup times.
- [ ] **Phase 4: Ephemeral Tracking & Notifications**
  - Implement real-time coordinate streaming, active notifications, and one-click cancellation/sickness reporting via room messaging.
