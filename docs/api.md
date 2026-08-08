# Matrix Event Flows & Operations - Carpool Coordinator

This document specifies the Matrix API integration flows, event types, and client-side operation schemas.

---

## 1. Authentication & Room Setup

Since we are using standard Matrix homeservers, authentication is handled directly by Matrix Login APIs.

### Login Flow

1. Client makes standard POST request to the user's Matrix Homeserver `/login` endpoint (or delegates via SSO/OIDC).
2. Server responds with a `homeserver_url`, `user_id` and `access_token`.
3. Client initialises the Matrix Client SDK locally with the token and executes `/sync`.

### Creating a Carpool Coordination Room

To spin up a new coordination circle:

1. Client calls `POST /_matrix/client/v3/createRoom` with:
   ```json
   {
     "preset": "private_chat",
     "name": "Oak Street School Carpool",
     "topic": "Coordinating daily drop-offs & pick-ups",
     "initial_state": [
       {
         "type": "m.room.encryption",
         "state_key": "",
         "content": {
           "algorithm": "m.megolm.v1.aes-sha2"
         }
       }
     ]
   }
   ```

2. Invite code generation is accomplished simply by sending standard Matrix Room Invites (`POST /_matrix/client/v3/rooms/{roomId}/invite`) to the invited user's `@username:homeserver.org`.

---

## 2. Dynamic Client-Side Workflows

The following event-driven flows illustrate how decentralization operates in practice.

### Workflow A: Loading & Sharing Schedules

```text
┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│ Owner Client │         │ Matrix Room  │         │ Participant  │
└──────┬───────┘         └──────┬───────┘         └──────┬───────┘
       │                        │                        │
       │ Parses iCal URLs       │                        │
       │ Locally & Creates      │                        │
       │ State Event config     │                        │
       ├───────────────────────>│                        │
       │                        │ Syncs State Event      │
       │                        ├───────────────────────>│
       │                        │                        │ Reads destination
       │                        │                        │ & calendar URL
```

1. **Setup**: One user sets up a coordinate target (e.g., school gym) and links an iCal feed url. They post an `org.carpool.schedules` state event.
2. **Synchronization**: Every client in the room syncs the state event, parses the `ical_feed_url` locally, geocodes coordinates if necessary, and populates their internal local calendar index.

### Workflow B: Signup Coordination & Route Generation

1. **Signup**: Each family navigates to the upcoming date in their application. They tap "Ride" or "Drive", which dispatches an `org.carpool.signup` message to the room.
2. **Assigning the Planner (Driver)**: The driver client listens for signup events. Once signup closes (e.g., 12 hours before event), the designated Driver's client gathers all active sign-ups.
3. **Route Construction**:
   * The Driver's app retrieves home addresses for all signing-up members from their respective `org.carpool.family.profile` state events.
   * Runs Traveling Salesperson Problem (TSP) client-side to arrange points in an optimal sequence.
   * Back-calculates pickup offsets (e.g., Event at 08:30 AM ➔ Dropoff 08:25 AM ➔ Pickup 2 at 08:12 AM ➔ Pickup 1 at 08:02 AM).
   * Generates a route polyline.
   * Publishes the computed times into the room as an `org.carpool.route` message.

---

## 3. Real-Time GPS Location Streams

Real-time tracking of active carpools must be instantaneous and completely secure.

### Location Sharing Protocol

1. Active driver begins routing and enables GPS streaming in the app.
2. Instead of standard high-latency message events (which bloat the room history timeline), the client uses Matrix To-Device messages or custom high-frequency ephemeral room events (e.g., standard Matrix `/sendToDevice` or custom room messages with low TTL / un-threaded room streams).
3. Listening clients receive coordinates directly via the standard Matrix `/sync` stream, decoding the coordinates to draw the driver's progress on local MapLibre map screens.
4. **ETA alerts**: Client-side background tasks compare active driver's current coordinates against scheduled pickup waypoints. If the estimated travel delay exceeds 5 minutes, the driver's client automatically dispatches an alert message to the room.
