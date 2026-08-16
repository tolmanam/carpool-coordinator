# Carpool Coordinator - Matrix Edition

An elegant, **fully decentralized, zero-cloud-cost**, offline-first mobile app built with **Flutter** for self-organized families, teams, and schools to coordinate carpooling, tracking, and schedules with absolute privacy using **Matrix**.

---

## 📸 Application Screenshots

| **Matrix Authentication & SSO** | **Schedule & Local Signups** |
| :---: | :---: |
| ![Login Screen](docs/screenshots/01_login.png) | ![Schedule Screen](docs/screenshots/02_schedule.png) |
| *Sign in with Matrix homeserver credentials or OIDC SSO* | *View synced iCal commutes, register to ride or drive* |

| **E2EE Family Circles** | **Active TSP Route & Dynamic Tracking** |
| :---: | :---: |
| ![Circles Screen](docs/screenshots/03_circles.png) | ![Active Route Screen](docs/screenshots/04_active_route.png) |
| *Manage Megolm v1 E2EE encrypted rooms & iCal feeds* | *TSP optimized waypoint pickup routes & delay alerts* |

---

## ⚡ Quick Start Guide

### Prerequisites
* **Flutter SDK**: v3.41+ (channel stable)
* **Dart SDK**: v3.11+
* **Java Development Kit (JDK)**: JDK 17 (for local Android builds)
* **Android SDK / Android Studio**: (required for running on Android emulator or native device builds)

---

### 🚀 Getting Started in 3 Steps

#### 1. Clone the Repository & Get Flutter Dependencies
```bash
git clone https://github.com/carpool-coordinator/carpool-coordinator.git
cd carpool-coordinator
flutter pub get
```

#### 2. Run Quality Checks & Unit Tests
Run Flutter unit and widget tests:
```bash
flutter test
```

#### 3. Launch the Application
Run the app on a connected Android device, emulator, or Linux desktop:
```bash
# Run on connected mobile device or emulator
flutter run

# Run on Linux desktop
flutter run -d linux
```

---

## 🚀 Key Advantages of the Matrix Paradigm

* **Zero Hosting Costs**: Eliminates backends, servers, and central databases. The application runs entirely on your phone (client-side), storing decentralized states and messages directly inside **Matrix rooms**.
* **Absolute Privacy**: Relies on Matrix's native **End-to-End Encryption (E2EE)** (Olm/Megolm) to encrypt children's names, home addresses, coordinates, and schedules, keeping them entirely invisible to homeserver admins.
* **No Separate Identity Provider**: Uses standard Matrix accounts (e.g., from matrix.org or self-hosted servers) for instant secure authentication.
* **Local-First & Offline Tolerant**: Clients function offline seamlessly using a local `sqflite` SQLite database, updating coordinates and schedules automatically when a network connection is resumed.

---

## 🛠️ Main Features

1. **Decentralized Matrix Authentication**
   * Instant sign-in using any standard Matrix homeserver credential or federated SSO / OIDC login.
2. **Local-First iCal Parser**
   * Client-side iCalendar (`.ics`) loader fetches school or activity calendars, parsing them directly into your local offline index.
3. **Decentralized Group Management**
   * Uses E2EE Matrix Rooms to represent family groups. Room joins, invites, and profiles translate straight into family coordination circles.
4. **Client-Side Route Calculations**
   * Runs local Traveling Salesperson Problem (TSP) algorithms directly on the driver's phone to plan the fastest pickup route and generate scheduled pickup ETAs.
5. **Real-Time Tracking & Delay Warnings**
   * Streams ephemeral GPS positions directly into Matrix rooms during active carpools, calculating dynamic arrival times and dispatching immediate room alerts (`org.carpool.alert`) if running behind schedule (>5 minutes).
6. **Driver Replacement & Participant Cancellation**
   * Allows drivers to request replacements or unassign themselves in emergencies and enables parents to cancel/opt out child rides dynamically.

---

## 📁 Project Structure

* `/lib/` - Flutter application source code.
  * `main.dart` - App entry point with Material Design 3 theme configuration and Provider setup.
  * `models/` - Data models (`Family`, `FamilyMember`, `Schedule`, `Signup`, `LocalIcalEvent`, `RouteWaypoint`).
  * `screens/` - UI screens (`LoginScreen`, `MainTabScreen`, `ScheduleScreen`, `CirclesScreen`, `ActiveRouteScreen`, `SettingsScreen`, `OnboardingScreen`).
  * `services/` - Core logic services (`DatabaseService` for SQLite, `MatrixService` for Matrix state, `IcalParserService`, `RouteOptimizerService`).
  * `widgets/` - Reusable UI components (`EmptyStateWidget`).
* `/test/` - Flutter unit and widget tests (`database_service_test.dart`, `ical_parser_service_test.dart`, `route_optimizer_service_test.dart`, `widgets_test.dart`, `user_stories_test.dart`).
* `/docs/` - Architecture documentation, user stories, and application screenshots (`docs/screenshots/`).

---

## 📱 Building & Testing the Android APK

### Automated GitHub Actions CD
1. **Trigger Manual Build**: Navigate to **Actions** -> **CD - Build Android APK** -> **Run workflow** in GitHub.
2. **Release Tag Build**: Push a git release tag starting with `v` (e.g. `git tag v1.0.0 && git push origin v1.0.0`).
3. **Download APK**: Download `app-release.apk` directly from the published GitHub Release assets or workflow run artifacts.

### Local Release APK Build
```bash
flutter build apk --release
```
The generated APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 🗺️ Roadmap & Future Enhancements

- [x] **Phase 1: Flutter Rework & Local Storage**
  - Migrated core application architecture to Flutter and Dart using Provider and `sqflite`.
- [x] **Phase 2: Local iCal Parser & TSP Route Optimizer**
  - RFC 5545 iCal feed parser and greedy Traveling Salesperson Problem (TSP) route optimizer with Haversine distance.
- [x] **Phase 3: User Stories & Test Coverage**
  - Added unit/widget tests for all user stories including driver replacements and participant cancellations.
- [ ] **Phase 4: Native Matrix SDK Bindings (E2EE Megolm)**
  - Integrate native `matrix-rust-sdk` Dart FFI bindings for full zero-trust Olm/Megolm E2EE encrypted sync with Matrix homeservers.
- [ ] **Phase 5: Background Location Streaming & Push Notifications**
  - Implement native Android background location tasks (`flutter_background_service`) and Matrix Push Gateway notifications for delay alerts.
