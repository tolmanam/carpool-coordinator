# Dynamic Active Route UI & Interactive Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded mockup in `ActiveRouteScreen` with a fully dynamic, database-driven active route interface featuring an interactive `flutter_map` OpenStreetMap map, real TSP waypoint ordering, authentic PIN handoff verification, and live attendance logging.

**Architecture:** `ActiveRouteScreen` gains an `initState` data-loading phase that queries `DatabaseService` for the active `Schedule`, all `Signup`s for `(scheduleId, eventTimestamp)`, and each rider's `FamilyMember` and `Family` profiles. The resolved coordinates are fed to `RouteOptimizerService.solveOptimalRoute()`, and the resulting `List<RouteWaypoint>` drives both the `flutter_map` visualization and the scrollable itinerary list. All check-in actions dispatch against real `memberId` values and validate against `signup.handoffPin`.

**Tech Stack:** Flutter 3.41+, `flutter_map ^7.0.2`, `latlong2 ^0.9.1`, existing `DatabaseService`, `RouteOptimizerService`, `MatrixService`, Material Design 3.

**Spec:** `docs/superpowers/specs/2026-11-14-dynamic-active-route-design.md`

## Global Constraints

- Multi-platform: must compile for Web (PWA), Android, and iOS without conditional imports in UI code.
- Material Design 3: use `Theme.of(context).colorScheme` properties; no hardcoded `Colors.*` except for semantic alert colors (red, orange, green).
- Offline tolerance: map tiles may fail to load; itinerary and all handoff/check-in actions must work without network.
- No hardcoded passenger names, destinations, PINs, or coordinates.
- Driver filtering: show only riders whose `signup.claimedByDriverId == driverMemberId` OR riders with `claimedByDriverId.isEmpty` when no claiming has occurred (single-driver event).
- `flutter_map` tile `userAgentPackageName`: `'org.carpool.coordinator'`.

## Review Focus

1. **Empty riders list** — if no active rider signups exist for the event, the screen must show `EmptyStateWidget` (not a blank or crashed route list). Test: Task 2.
2. **Unset driver coordinates (0.0, 0.0)** — if `Family.latitude == 0.0 && Family.longitude == 0.0`, show a persistent warning banner; do not pass (0.0, 0.0) to the TSP solver. Test: Task 2.
3. **`handoffPinRequired == true` with wrong PIN** — entering the wrong PIN must show an error snackbar and NOT record the check-in. Test: Task 4.
4. **Single rider route** — solveOptimalRoute with one rider must produce exactly 3 waypoints: driver_start → pickup → destination. Test: Task 2 (covered by existing route optimizer test; verify via widget test).
5. **Offline map tiles** — when `TileLayer` fails to load tiles, the itinerary and check-in buttons must remain functional (no unhandled exception). Test: Task 3 (widget test with network stubbed out).

---

## File Map

| File | Action | Responsibility |
|---|---|---|
| `pubspec.yaml` | Modify | Add `flutter_map ^7.0.2` and `latlong2 ^0.9.1` |
| `lib/screens/active_route_screen.dart` | Rewrite | Dynamic data loading, TSP wiring, flutter_map, itinerary list, PIN dialogs |
| `lib/services/database_service.dart` | Modify (add method) | `getSignupsByEvent(scheduleId, eventTimestamp)` returning filtered signups |
| `test/active_route_screen_test.dart` | Create | Widget tests covering data resolution, empty state, PIN validation, offline map |

---

## Task 1: Add `flutter_map` and `latlong2` dependencies

**Files:**
- Modify: `pubspec.yaml`

**Interfaces:**
- Produces: `flutter_map` and `latlong2` packages available to import in `active_route_screen.dart`

- [ ] **Step 1: Add dependencies to `pubspec.yaml`**

  In the `dependencies:` block, add:
  ```yaml
  flutter_map: ^7.0.2
  latlong2: ^0.9.1
  ```

- [ ] **Step 2: Verify `pubspec.yaml` is valid**

  Run: `grep -E "flutter_map|latlong2" pubspec.yaml`
  Expected: both lines present with correct versions.

- [ ] **Step 3: Commit**

  ```bash
  git add pubspec.yaml
  git commit -m "chore: add flutter_map and latlong2 dependencies"
  ```

---

## Task 2: Add `getSignupsByEvent` to `DatabaseService`

**Files:**
- Modify: `lib/services/database_service.dart` (after line 276, alongside existing `getSignups`)
- Test: `test/database_service_test.dart` (add test to existing file)

**Interfaces:**
- Produces: `Future<List<Signup>> getSignupsByEvent(String scheduleId, int eventTimestamp)` — returns all signups matching both `schedule_id` and `event_timestamp`, ordered by `role DESC` (drivers first).

- [ ] **Step 1: Write failing test in `test/database_service_test.dart`**

  ```dart
  test('getSignupsByEvent returns only signups for matching scheduleId and eventTimestamp', () async {
    final db = DatabaseService();
    await db.initDatabase(inMemoryPath: inMemoryDatabasePath);
    final ts1 = 1700000000000;
    final ts2 = 1700000001000;
    await db.insertSignup(Signup(id: 'a', scheduleId: 'sched1', eventTimestamp: ts1, memberId: 'm1', role: 'driver', status: 'scheduled'));
    await db.insertSignup(Signup(id: 'b', scheduleId: 'sched1', eventTimestamp: ts2, memberId: 'm2', role: 'rider', status: 'scheduled'));
    await db.insertSignup(Signup(id: 'c', scheduleId: 'sched2', eventTimestamp: ts1, memberId: 'm3', role: 'rider', status: 'scheduled'));

    final results = await db.getSignupsByEvent('sched1', ts1);
    expect(results.length, equals(1));
    expect(results.first.memberId, equals('m1'));
  });
  ```

- [ ] **Step 2: Run test to verify it fails**

  Run: `flutter test test/database_service_test.dart --name "getSignupsByEvent"`
  Expected: FAIL — method not found.

- [ ] **Step 3: Implement `getSignupsByEvent` in `lib/services/database_service.dart`**

  Signature: `Future<List<Signup>> getSignupsByEvent(String scheduleId, int eventTimestamp) async`

  Query `cached_signups` with `WHERE schedule_id = ? AND event_timestamp = ?` and `ORDER BY role DESC` (so `'rider'` < `'driver'` alphabetically, putting drivers first). Map results through `Signup.fromMap`.

- [ ] **Step 4: Run test to verify it passes**

  Run: `flutter test test/database_service_test.dart --name "getSignupsByEvent"`
  Expected: PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/services/database_service.dart test/database_service_test.dart
  git commit -m "feat: add getSignupsByEvent to DatabaseService"
  ```

---

## Task 3: Rewrite `ActiveRouteScreen` with dynamic data loading and `flutter_map`

**Files:**
- Rewrite: `lib/screens/active_route_screen.dart`
- Create: `test/active_route_screen_test.dart`

**Interfaces:**
- Consumes (Task 2): `dbService.getSignupsByEvent(scheduleId, eventTimestamp) → Future<List<Signup>>`
- Consumes (existing): `dbService.getFamilyMembers(matrixId)`, `dbService.getFamily(matrixId)`, `dbService.getAllFamilyMembers()`, `dbService.getSchedules()`
- Consumes (existing): `RouteOptimizerService.solveOptimalRoute(driverHome, destination, riders, eventTimestamp) → List<RouteWaypoint>`, `RouteOptimizerService.resolveRiderLocation(member, family, eventTimestamp) → LocationCoord`
- Consumes (existing): `matrixService.username` (String, logged-in Matrix ID), `matrixService.sendAttendanceCheckin(scheduleId, eventTimestamp, memberId, action, driverId)`
- Produces: Rewritten `ActiveRouteScreen` widget; no new public API.

### State fields (add to `_ActiveRouteScreenState`):

```dart
bool _isLoading = true;
String? _loadError;
Schedule? _schedule;
List<RouteWaypoint> _waypoints = [];
List<Signup> _riderSignups = [];          // rider signups for this driver
Map<String, FamilyMember> _memberById = {}; // memberId → FamilyMember
Signup? _driverSignup;
```

Remove: `int _etaMinutes = 25` (ETA now comes from `RouteWaypoint.estimatedTime`).
Keep: `bool _activeDrive`, `bool _delayReported`, `Set<String> _checkedInMembers`.

### Data-loading method (`_loadRouteData`):

```dart
Future<void> _loadRouteData() async
```

Steps inside:
1. Call `dbService.getSignupsByEvent(widget.scheduleId, widget.eventTimestamp)`.
2. Find driver signup: first signup where `role == 'driver' && status != 'canceled'`.
3. Determine `driverMemberId` = `driverSignup?.memberId ?? ''`.
4. Filter rider signups: `role == 'rider' && status != 'canceled'` AND (`claimedByDriverId == driverMemberId` OR `claimedByDriverId.isEmpty`).
5. Fetch all `FamilyMember`s via `dbService.getAllFamilyMembers()`; build `Map<String, FamilyMember>` keyed by `memberId`.
6. For each rider signup, look up its `FamilyMember`. Look up its `Family` via `dbService.getFamily(member.matrixId)`. Call `RouteOptimizerService.resolveRiderLocation(member, family, eventTimestamp)`.
7. Fetch driver's `Family` via `dbService.getFamily(matrixService.username)`. Check for (0.0, 0.0) — set `_loadError = 'missing_driver_coords'` if so, but continue with empty waypoints.
8. Fetch `Schedule` from `dbService.getSchedules()`, find one matching `widget.scheduleId`.
9. Build `LocationCoord destination` from `schedule.latitude`, `schedule.longitude`, `memberId: 'destination'`.
10. Call `RouteOptimizerService.solveOptimalRoute(driverHome, destination, riderCoords, widget.eventTimestamp)`.
11. `setState(() { _isLoading = false; _waypoints = ...; _riderSignups = ...; _memberById = ...; })`.

### Map widget (replace the static container):

```dart
SizedBox(
  height: 240,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(16),
    child: FlutterMap(
      options: MapOptions(
        initialCameraFit: CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(_waypointLatLngs()),
          padding: const EdgeInsets.all(40),
        ),
        minZoom: 3,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'org.carpool.coordinator',
          errorTileCallback: (tile, error, stackTrace) {},
        ),
        PolylineLayer(polylines: [_buildRoutePolyline()]),
        MarkerLayer(markers: _buildMarkers()),
      ],
    ),
  ),
)
```

Helper `_waypointLatLngs()` → `List<LatLng>` from `_waypoints`.  
Helper `_buildRoutePolyline()` → `Polyline` with `color: Theme.of(context).colorScheme.primary`, `strokeWidth: 4.0`.  
Helper `_buildMarkers()` → `List<Marker>`:
  - Driver start: blue car icon at index 0.
  - Each pickup: numbered indigo circle badge with child initials.
  - Destination: green flag icon at last waypoint.

### Empty state:

In `build()`, when `_isLoading == false && _riderSignups.isEmpty`:
```dart
return EmptyStateWidget(
  icon: Icons.directions_car_outlined,
  title: 'No riders for this carpool',
  description: 'No active rider signups found for this occurrence.',
  buttonText: 'Back to Schedule',
  onButtonPressed: () => Navigator.pop(context),
);
```

### Missing driver coordinates banner:

When `_loadError == 'missing_driver_coords'`, render a `MaterialBanner` at top:
```dart
MaterialBanner(
  content: const Text('Your home address is not set. Route calculation unavailable.'),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Go to Settings'),
    ),
  ],
)
```

### Itinerary list (replace static `ListTile`s):

Replace the hardcoded pickup items with a `ListView.builder` over `_waypoints`. For each `RouteWaypoint`:
- Display stop number, `DateFormat('h:mm a').format(DateTime.fromMillisecondsSinceEpoch(wp.estimatedTime))`, and address lookup from `_memberById[wp.memberId]?.name ?? 'Unknown'`.
- For pickup waypoints: render booster chip if `member.requiresBoosterSeat`, red medical chip if `member.medicalNotes.isNotEmpty`.
- Render "Child Boarded" / "Child Delivered" buttons per rider (see Task 4 for PIN logic).

- [ ] **Step 1: Write failing widget tests in `test/active_route_screen_test.dart`**

  ```dart
  // Test A: Shows EmptyStateWidget when no rider signups exist
  testWidgets('shows empty state when no riders found', (tester) async {
    // Setup: DB with schedule + driver signup, no rider signups
    // Pump ActiveRouteScreen
    // Expect: find EmptyStateWidget text 'No riders for this carpool'
  });

  // Test B: Shows warning banner when driver family coords are (0.0, 0.0)
  testWidgets('shows missing coords banner when driver family unset', (tester) async {
    // Setup: DB with schedule + driver signup + rider signup; Family with lat/lng = 0.0
    // Pump ActiveRouteScreen
    // Expect: find MaterialBanner with 'home address is not set'
  });

  // Test C: Renders correct number of waypoint markers for 2 riders
  testWidgets('renders 4 waypoints for 2 rider signups', (tester) async {
    // Setup: DB with 1 driver + 2 riders with valid coordinates
    // Pump ActiveRouteScreen
    // Expect: find 4 ListTile or waypoint cards (start + 2 pickups + destination)
  });
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Run: `flutter test test/active_route_screen_test.dart`
  Expected: FAIL (widget not yet rewritten).

- [ ] **Step 3: Rewrite `lib/screens/active_route_screen.dart`**

  Implement per the state fields, `_loadRouteData`, map widget, empty state, coordinates banner, and itinerary list specifications above. Import `flutter_map`, `latlong2`, `database_service.dart`, `route_optimizer_service.dart`, `models/models.dart`, `intl`, `empty_state_widget.dart`.

- [ ] **Step 4: Run tests to verify they pass**

  Run: `flutter test test/active_route_screen_test.dart`
  Expected: all 3 tests PASS.

- [ ] **Step 5: Run full test suite**

  Run: `flutter test`
  Expected: all tests PASS (no regressions).

- [ ] **Step 6: Commit**

  ```bash
  git add lib/screens/active_route_screen.dart test/active_route_screen_test.dart
  git commit -m "feat: wire ActiveRouteScreen to real database, TSP, and flutter_map"
  ```

---

## Task 4: Authentic PIN handoff verification and check-in dispatch

**Files:**
- Modify: `lib/screens/active_route_screen.dart` (within the itinerary list built in Task 3)
- Modify: `test/active_route_screen_test.dart` (add PIN tests)

**Interfaces:**
- Consumes: `signup.handoffPinRequired` (bool), `signup.handoffPin` (String), `signup.memberId`
- Consumes: `matrixService.sendAttendanceCheckin(scheduleId, eventTimestamp, memberId, action, driverId)`
- No new public API produced.

### "Child Boarded" button logic:

```dart
onPressed: () async {
  bool verified = true;
  if (signup.handoffPinRequired && signup.handoffPin.isNotEmpty) {
    verified = await _showPinDialog(signup.handoffPin);
  }
  if (!verified) return;
  await matrixService.sendAttendanceCheckin(
    widget.scheduleId,
    widget.eventTimestamp,
    signup.memberId,
    signup.handoffPinRequired ? 'pickup_pin_verified' : 'pickup',
    matrixService.username,
  );
  setState(() => _checkedInMembers.add('${signup.memberId}_pickup'));
}
```

### `_showPinDialog(expectedPin)` → `Future<bool>`:

Dialog with a `TextField(keyboardType: TextInputType.number, obscureText: true)`.  
On "Verify PIN": compare `controller.text.trim() == expectedPin`. If wrong, show `SnackBar('Invalid PIN')` and return `false`. If correct, return `true`.  
On "Bypass / Skip" (allow in-person handoff): return `true` without PIN check.  
Return `false` on dialog dismiss.

- [ ] **Step 1: Write failing PIN tests**

  ```dart
  // Test D: Wrong PIN does not record check-in
  testWidgets('wrong PIN shows error and does not record check-in', (tester) async {
    // Setup: rider signup with handoffPinRequired=true, handoffPin='5678'
    // Tap 'Child Boarded'
    // Enter '0000' in PIN dialog
    // Tap 'Verify PIN'
    // Expect: SnackBar with 'Invalid PIN' visible
    // Expect: _checkedInMembers does NOT contain the pickup key
  });

  // Test E: Correct PIN records check-in
  testWidgets('correct PIN records check-in', (tester) async {
    // Setup: rider signup with handoffPinRequired=true, handoffPin='5678'
    // Tap 'Child Boarded'
    // Enter '5678' in PIN dialog
    // Tap 'Verify PIN'
    // Expect: check-in button changes to 'Pickup Recorded' state
  });

  // Test F: No PIN required records check-in immediately
  testWidgets('no PIN required records check-in without dialog', (tester) async {
    // Setup: rider signup with handoffPinRequired=false
    // Tap 'Child Boarded'
    // Expect: no PIN dialog appears; check-in button shows 'Pickup Recorded'
  });
  ```

- [ ] **Step 2: Run tests to verify they fail**

  Run: `flutter test test/active_route_screen_test.dart --name "PIN"`
  Expected: FAIL.

- [ ] **Step 3: Implement `_showPinDialog` and wire "Child Boarded" / "Child Delivered" buttons**

  Add `_showPinDialog(String expectedPin) → Future<bool>` to `_ActiveRouteScreenState`. Wire "Child Boarded" and "Child Delivered" buttons per the logic above.

- [ ] **Step 4: Run PIN tests to verify they pass**

  Run: `flutter test test/active_route_screen_test.dart --name "PIN"`
  Expected: PASS.

- [ ] **Step 5: Run full test suite**

  Run: `flutter test`
  Expected: all tests PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add lib/screens/active_route_screen.dart test/active_route_screen_test.dart
  git commit -m "feat: implement authentic PIN handoff verification in ActiveRouteScreen (US-111, US-212)"
  ```

---

## Task 5: Wire `BackgroundStreamingService` to driver's real resolved coordinates

**Files:**
- Modify: `lib/screens/active_route_screen.dart` (the "Start Drive" button handler)

**Interfaces:**
- Consumes: `BackgroundStreamingService.startBackgroundLocationStreaming(scheduleId, initialLat: double, initialLng: double)`
- Consumes: driver home `LocationCoord` resolved in `_loadRouteData` (store as `LocationCoord? _driverHome` state field)
- No new public API.

### "Start Drive" button handler change:

Replace the hardcoded `initialLat: 34.0522, initialLng: -118.2437` with `initialLat: _driverHome?.latitude ?? 0.0, initialLng: _driverHome?.longitude ?? 0.0`.

Also add `BackgroundStreamingService` to `Provider` reads in `main.dart` (if not already registered; check and add only if missing).

- [ ] **Step 1: Store `_driverHome` in `_loadRouteData`**

  Add `LocationCoord? _driverHome;` state field. Assign it in `_loadRouteData` after resolving driver family coordinates.

- [ ] **Step 2: Update "Start Drive" button to use `_driverHome`**

  Replace hardcoded coordinates in `BackgroundStreamingService.startBackgroundLocationStreaming` call.

- [ ] **Step 3: Verify `BackgroundStreamingService` is in `main.dart` Provider tree**

  Run: `grep -n "BackgroundStreamingService" lib/main.dart`
  If missing: add `ChangeNotifierProvider(create: (_) => BackgroundStreamingService(matrixService: matrixService))` to `MultiProvider`.

- [ ] **Step 4: Run full test suite**

  Run: `flutter test`
  Expected: all tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add lib/screens/active_route_screen.dart lib/main.dart
  git commit -m "feat: use real driver coordinates for background GPS streaming start"
  ```

---

## Task 6: Update `README.md` roadmap checklist

**Files:**
- Modify: `README.md` lines 124–141 (Phases 4–7 checklist items currently marked `[ ]`)

- [ ] **Step 1: Update Phase 4–7 checklist entries in README**

  Change:
  ```markdown
  - [ ] **Phase 4: Native Matrix SDK Bindings (E2EE Megolm)**
  - [ ] **Phase 5: Background Location Streaming & Push Notifications**
  - [ ] **Phase 6: Advanced Family Administration & Privacy Enhancements**
  - [ ] **Phase 7: Advanced Driver Safety, Liability & Social Dynamics**
  ```
  To `[x]` with a brief note reflecting actual status (REST fallback, simulated GPS, implemented in code).

- [ ] **Step 2: Run full test suite one final time**

  Run: `flutter test`
  Expected: all tests PASS.

- [ ] **Step 3: Final commit**

  ```bash
  git add README.md
  git commit -m "docs: sync README.md roadmap checklist with actual implementation status"
  ```
