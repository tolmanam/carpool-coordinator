# Carpool Coordinator - Release & Deployment Guide

This document outlines the end-to-end best practices, release process, mobile installation steps, and deployment configuration for the **Carpool Coordinator** app.

---

## 📋 Pre-Release Readiness Checklist

Before building or installing the app on physical mobile devices or submitting to application stores, verify the following checklist:

| Category | Requirement / Best Practice | Status |
| :--- | :--- | :---: |
| **Application Identity** | Package name configured as `org.carpool.coordinator` | ✅ |
| **Version Strategy** | Semantic versioning set in `pubspec.yaml` (`1.0.0+1`) and `build.gradle` | ✅ |
| **Permissions** | Internet, Fine/Coarse Location, and Background Location permissions in `AndroidManifest.xml` | ✅ |
| **Matrix Homeserver** | Default set to `https://matrix.org`, with multi-homeserver circle selection enabled | ✅ |
| **Offline Architecture** | SQLite local persistence (`sqflite`) and state caching initialized | ✅ |
| **Testing** | Automated unit tests and widget tests passing via `flutter test` | ✅ |
| **CI/CD** | GitHub Actions workflows configured for build and release automation | ✅ |

---

## 📱 Installing on Android Physical Devices

To install the application on an Android smartphone or tablet prior to Google Play Store publishing:

### Method 1: Local Release APK Build

1. **Build the APK**:
   ```bash
   flutter build apk --release
   ```
2. **Locate Output File**:
   The generated binary will be placed at:
   `build/app/outputs/flutter-apk/app-release.apk`
3. **Install via ADB**:
   Connect your Android device via USB with USB Debugging enabled, then run:
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```
4. **Direct Phone Installation**:
   Transfer `app-release.apk` to your Android device via cloud storage or direct cable, enable "Install from Unknown Sources" when prompted, and tap the APK to install.

---

## 🤖 Building Android App Bundle (AAB) for Google Play Store

For official distribution via the Google Play Console:

1. **Build App Bundle**:
   ```bash
   flutter build appbundle --release
   ```
2. **Output Location**:
   `build/app/outputs/bundle/release/app-release.aab`
3. **Signing Configurations**:
   Ensure a production upload keystore is configured in `android/key.properties` and referenced in `android/app/build.gradle`.

---

## 🍎 iOS Deployment Preparation (Upcoming Phase)

When expanding to iOS devices:

1. **Bundle Identifier**: Set `org.carpool.coordinator` in Xcode project settings.
2. **Info.plist Location Usage Descriptions**:
   - `NSLocationWhenInUseUsageDescription`: "Carpool Coordinator uses your location to show pickup route progress."
   - `NSLocationAlwaysAndWhenInUseUsageDescription`: "Carpool Coordinator streams your location to passenger parents during active carpools."
3. **Build Command**:
   ```bash
   flutter build ipa --release
   ```

---

## 🌐 Matrix Homeserver Configuration & Multi-Circle Support

- **Default Homeserver**: The application defaults to `https://matrix.org` for zero-configuration startup.
- **Custom Homeservers**: Users can specify self-hosted or private homeservers (e.g., `https://matrix.school.org`) during login.
- **Multi-Server Circles**: Each carpool circle/schedule can operate on its own Matrix homeserver (`homeserverUrl` property on `Schedule`), isolating data and access per school or team organization.

---

## 🔄 Automated CI/CD Workflows

The repository includes GitHub Actions CI/CD pipeline definitions in `.github/workflows/`:
- `ci.yml`: Runs on every push or pull request to run `flutter test` and static linting.
- `cd.yml`: Triggers on release tags (`v*`) or manual dispatch to compile `app-release.apk` and publish GitHub Release artifacts automatically.
