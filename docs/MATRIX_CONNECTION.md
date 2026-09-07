# Matrix Connection & Lifecycle Specification - Carpool Coordinator

This document defines the requirements, architecture, and best practices for establishing, validating, maintaining, and recovering connections to Matrix homeservers in the **Carpool Coordinator** application.

The design principles and requirements contained herein reference best practices from leading open-source Matrix clients:
- **FluffyChat** ([krille-chan/fluffychat](https://github.com/krille-chan/fluffychat)) - Flutter-based Matrix client emphasizing resilience and mobile usability.
- **Element Web** ([element-hq/element-web](https://github.com/element-hq/element-web)) - Reference Matrix web client maintaining robust sync lifecycle and discovery protocols.
- **Cinny** ([cinnyapp/cinny](https://github.com/cinnyapp/cinny)) - Lightweight Matrix client with clean state and device management patterns.
- **Matrix Client-Server API Specification** ([spec.matrix.org](https://spec.matrix.org/latest/client-server-api/)) - The official Matrix Client-Server API reference.

---

## 1. Homeserver Discovery & URL Resolution

Before attempting login or registration, the client MUST resolve and validate the target Matrix homeserver endpoint to ensure compatibility and correct routing.

### 1.1 Well-Known Endpoint Discovery (`.well-known/matrix/client`)
1. **Discovery Request**: Given a user-provided domain (e.g. `example.com` or `matrix.org`), the client MUST issue an HTTP GET request to `https://<domain>/.well-known/matrix/client`.
2. **Canonical Base URL Extraction**: If the endpoint returns HTTP 200 with JSON payload containing `m.homeserver.base_url`, the client MUST use that `base_url` for all subsequent Matrix API requests (`/_matrix/client/v3/...`).
3. **Fallback Routing**: If `.well-known` resolution fails (e.g. 404 Not Found, DNS resolution failure, or network timeout), the client MUST fall back to `https://<domain>` directly after verifying the presence of HTTP/HTTPS scheme prefixes.
4. **URL Sanitization**: All homeserver URLs MUST be sanitized by stripping trailing slashes and ensuring `https://` default scheme if omitted.

### 1.2 Homeserver Connectivity Verification
1. **Versions Endpoint**: The client MAY verify server readiness and supported specification versions by calling `GET /_matrix/client/versions`.

---

## 2. Session Authentication & Token Management

Authentication establishes a persistent session between the client device and the Matrix homeserver.

### 2.1 Password & SSO Login Flow
1. **User Identifier Normalization**: Full Matrix IDs (e.g. `@alice:matrix.org`) or localpart usernames (`alice`) MUST be normalized prior to payload dispatch.
2. **Device ID Binding**: Login requests (`POST /_matrix/client/v3/login`) MUST include a unique `device_id` (or request generation from the server) and an informative `initial_device_display_name` (e.g., `"Carpool Coordinator App"`).
3. **Session Store**: Upon successful login (HTTP 200), the client MUST securely persist:
   - `access_token`
   - `user_id` (full `@localpart:domain` Matrix ID)
   - `device_id`
   - `homeserver` URL

### 2.2 Token Invalidation (`401 M_UNKNOWN_TOKEN`)
1. **Invalid Token Detection**: When any Matrix API call returns HTTP 401 with error code `M_UNKNOWN_TOKEN` or `M_UNAUTHORIZED`, the client MUST mark the session as invalid.
2. **Session Cleanup**: The client MUST purge stored session credentials (`access_token`, `sync_token`) and notify the UI to prompt user re-authentication.

---

## 3. Long-Polling Sync Loop (`/_matrix/client/v3/sync`)

The Matrix `/sync` endpoint is the central event stream mechanism for real-time room state updates, signups, location streams, and chat messages.

### 3.1 Sync Polling Configuration
1. **Long Polling Timeout**: Active sync calls MUST use a long-polling `timeout` parameter (e.g. `timeout=30000` ms) to prevent excessive HTTP request overhead while allowing immediate push response delivery from the homeserver.
2. **Batch Token Continuity**: Initial sync calls MUST omit the `since` parameter. Subsequent sync requests MUST supply the `next_batch` token received from the preceding successful sync response as the `since` query parameter.
3. **Filter Optimization**: Sync requests MAY include a `filter` parameter or preset filter to restrict synced events to relevant room types and message categories (`org.carpool.*`, `m.room.message`, `m.room.state`).

---

## 4. Connection Resilience, Errors & Exponential Backoff

Network interruptions, server restarts, and rate limiting require robust retry handling following established Matrix client patterns.

### 4.1 Exponential Backoff with Jitter Strategy
1. **Failure Retries**: Upon network failures (e.g., socket timeout, host unreachable) or HTTP server errors (HTTP 5xx), the client MUST NOT retry immediately in a tight loop.
2. **Backoff Parameters**:
   - Initial Backoff: 2.0 seconds
   - Backoff Multiplier: 2.0
   - Maximum Backoff: 60.0 seconds
   - Jitter: Randomization factor between ±20% applied to avoid thundering herd issues across devices.
3. **Reset on Success**: A successful HTTP 200 response resets the exponential backoff delay back to zero.

### 4.2 Rate Limit Handling (`429 M_LIMIT_EXCEEDED`)
1. **Retry-After Compliance**: If the homeserver returns HTTP 429 (`M_LIMIT_EXCEEDED`), the client MUST inspect the `retry_after_ms` field in the response JSON.
2. **Wait Duration**: The client MUST delay subsequent requests for at least `retry_after_ms` (or a default 5-second delay if omitted) before re-attempting the request.

---

## 5. Offline Queueing & Network Recovery

To guarantee a seamless experience for drivers in rural areas with poor connectivity, the client operates offline-first with background queuing.

### 5.1 Local Persistence & Optimistic Writes
1. **Local SQLite Caching**: All outgoing events (`org.carpool.signup`, `org.carpool.location`, `org.carpool.alert`, `m.room.message`) MUST be committed locally to SQLite before network transmission.
2. **Pending Event Queue**: When offline or when network requests fail, events MUST be stored in the `pending_events` table with unique transaction IDs (`txn_id`).

### 5.2 Automatic Flush on Reconnection
1. **Network Status Recovery**: Upon transitioning from offline/disconnected state to online state, the client MUST trigger `flushPendingEvents()`.
2. **Idempotent Dispatch**: Retried requests MUST reuse the unique transaction ID in the PUT request URI (`/_matrix/client/v3/rooms/{roomId}/send/{eventType}/{txnId}`) to prevent duplicate event creation on the homeserver.

---

## 6. Device Key & Encryption Verification

Matrix End-to-End Encryption (E2EE) management ensures payload privacy across circles.

### 6.1 Device Key Registry
1. **Key Upload (`/_matrix/client/v3/keys/upload`)**: Upon session initialization, the client MUST upload identity and one-time keys (`Curve25519` and `Ed25519`).
2. **Key Query (`/_matrix/client/v3/keys/query`)**: The client queries public keys for circle participants to establish encrypted Megolm sessions.
3. **Verification Tracking**: Local device trust states (`Verified`, `Unverified`, `Blocked`) MUST be persisted in client storage and configurable via Settings.
