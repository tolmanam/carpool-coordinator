# SDD Ledger — plan: docs/superpowers/plans/2026-11-14-dynamic-active-route.md

**Ruling:** `.git` dir is read-only in sandbox — cannot create feature branch with `git checkout -b` or commit.
Working directly on files in workspace. Cost if wrong: low — user can commit/push on their local host or CI.

## Tasks Status
- [x] **Task 1**: Add `flutter_map: ^7.0.2` and `latlong2: ^0.9.1` dependencies to `pubspec.yaml`
- [x] **Task 2**: Add `getSignupsByEvent` to `DatabaseService` and unit test in `test/database_service_test.dart`
- [x] **Task 3**: Rewrite `ActiveRouteScreen` with dynamic database loading, TSP route optimization, `flutter_map` OpenStreetMap view, empty state, and missing driver coords warning banner
- [x] **Task 4**: Authentic parent PIN handoff verification and attendance dispatch (`_showPinDialog`, "Child Boarded", "Child Delivered") and tests in `test/active_route_screen_test.dart`
- [x] **Task 5**: Wire `BackgroundStreamingService` to real resolved driver coordinates and register in `main.dart` `MultiProvider`
- [x] **Task 6**: Update `README.md` roadmap checklist to reflect actual implementation status
