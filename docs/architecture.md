# Matrix-Centric Architecture - Carpool Coordinator

This document details the architectural pivot to a **fully decentralized, zero-backend cloud cost, Matrix-based, client-side first architecture** for the **Carpool Coordinator**.

---

## 1. Decentralization Philosophy: Why Matrix?

To achieve **zero cloud hosting/database maintenance costs** and maximum privacy, we eliminate the centralized PostgreSQL/Node.js/Go backend server. Instead, we use **Matrix** (an open standard for secure, decentralized, real-time communication) as the virtual backbone for:

* **Identity & Authentication**: Users authenticate with any home-server of choice (e.g., matrix.org, a self-hosted homeserver, or community homeservers) using Matrix credentials. No separate OIDC infrastructure is required!
* **Group Management & Trust**: Matrix Rooms act as the boundary for "Family Groups." Joining a room represents joining a coordination group. Room power levels manage invite permissions and configuration changes.
* **State Synchronization**: Matrix State Events (`m.room.state`) are stored and synchronized seamlessly across all homeservers and clients. We can define custom state events (e.g., `org.carpool.family.profile`, `org.carpool.schedules`) to sync configuration.
* **Real-Time Communication**: Ephemeral location streams and status notifications (sick days, cancellations) are sent as standard Matrix events (`org.carpool.location`, `org.carpool.status`) directly to room participants.

---

## 2. Shift to Client-Side Processing

All heavy computational work is offloaded entirely to individual user clients (Mobile App via React Native / Expo):

```text
┌────────────────────────────────────────────────────────────────────────┐
│                          Mobile Client (Expo)                          │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │  iCal Schedule Puller   │            │  TSP Route Calculator   │   │
│   │  (Direct client fetch)  │            │ (In-app Valhalla/OSRM)  │   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
│   ┌─────────────────────────┐            ┌─────────────────────────┐   │
│   │  Local SQLite Storage   │            │    Matrix Client SDK    │   │
│   │  (WatermelonDB / CRDT)  │            │(Sync / Send Room Events)│   │
│   └─────────────────────────┘            └─────────────────────────┘   │
│                                                                        │
└───────────────────────────────────┬────────────────────────────────────┘
                                    │
                                    │ Matrix Client-Server API
                                    ▼
┌────────────────────────────────────────────────────────────────────────┐
│                          Decentralized Matrix                          │
│                          Federated Homeservers                         │
│                     (matrix.org, self-hosted, etc.)                    │
└────────────────────────────────────────────────────────────────────────┘
```

### Client Responsibilities:

1. **iCal Fetching & Parsing**: The client app regularly wakes up (or triggers on open) to fetch the configured raw `.ics` feed URLs directly from the Web. It parses the schedule locally and maps them to events.
2. **Geocoding & Route Optimization**: Rather than querying a central routing server, the client utilizes local routing modules or public, free tier geocoding and routing APIs (or lightweight client-side libraries like `turf.js` for straight-line heuristics/simple TSP).
3. **Data Storage**: All persistent structures (e.g., local logs, personal configurations, raw calendars) are saved in a local, encrypted SQLite database. Group-level definitions are fetched and synced from the Matrix Room State.

---

## 3. Matrix Protocol Mapping

The Carpool Coordinator maps its operational concepts onto native Matrix Room primitives:

| Carpool Concept | Matrix Primitive | Implementation Details |
|---|---|---|
| **Family Group / Cluster** | **Matrix Room** | A private, end-to-end encrypted (E2EE) Matrix room. |
| **Authentication** | **Homeserver Login** | Client logs in to their Matrix homeserver using password or SSO. |
| **User Identity** | **Matrix ID (`@user:server.org`)**| Unique identification. Display names and avatars are reused. |
| **Group Profile / Homes** | **Room State Event** | A custom state event `org.carpool.group` containing a JSON dictionary of member home coordinates (optionally encrypted). |
| **Shared Schedules** | **Room State Event** | A custom state event `org.carpool.schedule` outlining shared regular pickup locations (school, sport arenas). |
| **Sign-ups / Shifts** | **Room Message Event** | `org.carpool.signup` representing who is driving / riding for a specific date. |
| **Real-time Live Location**| **Room Ephemeral Event** | Matrix `m.receipt` / `org.carpool.location` custom message streaming coordinates while active. |
| **Sick/Cancellation Alert**| **Room Message Event** | Standard messaging context `org.carpool.alert` with specific structured details. |

---

## 4. Addressing Technical Challenges

While this reduces hosting costs to absolute zero, we must solve several constraints inherent in decentralized client-only processing:

### A. The "Who Calculates the Route?" Coordination Challenge

Because there is no central server to compute optimal routing, a coordination consensus is required:

* **The Solution**: The designated **Driver** for a given schedule/shift performs the calculation.
* **The Flow**:
  1. Members publish their availability/signup requests as Matrix events into the room.
  2. The Driver's app compiles these signups, extracts home locations from the Room State, calculates the optimal route using client-side libraries, and publishes the final schedule/pickup ETAs to the Matrix room as an updated `org.carpool.route` event.
  3. Other participants' apps listen for this event and render it locally.

### B. Accessing Raw `.ics` Calendars Behind Firewalls (CORS)

Clients fetching arbitrary iCal URLs may run into CORS (Cross-Origin Resource Sharing) restrictions on web browsers (though not an issue for native iOS/Android React Native apps).

* **The Solution**: Native mobile clients execute HTTP requests bypassing CORS. For the web-app companion, users can optionally use public, free proxy bypasses or standard Matrix file uploads (allowing a family to manually upload/attach `.ics` files directly into the Matrix room media repository).

### C. Offline Support & Sync Latency

If some group members are offline, they must not block coordination.

* **The Solution**: Matrix stores events on the federated homeservers. Once an offline family returns online, their client automatically performs a standard Matrix `/sync` call to retrieve all updates, re-evaluate schedules, and refresh local databases.
* Matrix's built-in Conflict Resolution (based on DAG topological sorting and event timestamps) handles concurrent updates to schedules smoothly.
