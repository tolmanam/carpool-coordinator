# Client-Side Flows & Internal APIs - Carpool Coordinator

This document specifies the internal module contracts, background task interfaces, and the routing/TSP engine logic running client-side in Dart/Flutter. For Matrix server connection handling, homeserver discovery, exponential backoff sync loops, and offline queueing requirements, reference [Matrix Connection Specification](MATRIX_CONNECTION.md).

---

## 1. Matrix Authentication & Room Setup Flows

Since this is a decentralized, serverless model, we interface directly with the user's selected Matrix homeserver via `MatrixService` (`lib/services/matrix_service.dart`).

```dart
class MatrixClientConfig {
  final String baseUrl;
  final String userId;
  final String accessToken;
  final String deviceId;

  MatrixClientConfig({
    required this.baseUrl,
    required this.userId,
    required this.accessToken,
    required this.deviceId,
  });
}

class MatrixDevice {
  final String deviceId;
  final String? displayName;
  final String? lastSeenIp;
  final int? lastSeenTs;
  final String verificationStatus; // 'Verified' | 'Unverified' | 'Blocked'

  MatrixDevice({
    required this.deviceId,
    this.displayName,
    this.lastSeenIp,
    this.lastSeenTs,
    required this.verificationStatus,
  });
}
```

---

## 2. iCal Parsing & Distributed Synchronization Service

We implement client-side iCal feed parsing in `IcalParserService` (`lib/services/ical_parser_service.dart`) with local SQLite synchronization via `DatabaseService`.

```dart
class IcalParserService {
  /// Parses RFC 5545 iCal feed string into local event instances.
  List<LocalIcalEvent> parseIcalString(String icalContent, String scheduleId) {
    // 1. Extract VEVENT blocks
    // 2. Parse SUMMARY, DTSTART, DTEND, RRULE attributes
    // 3. Resolve recurring occurrences
    // 4. Return list of LocalIcalEvent objects
    return [];
  }
}
```

---

## 3. Client-Side Route Optimizer (TSP Solver)

The assigned driver's client runs a Traveling Salesperson Problem (TSP) solver locally in `RouteOptimizerService` (`lib/services/route_optimizer_service.dart`) to plan optimal routing waypoints and times.

```dart
class RouteWaypoint {
  final String id;
  final String scheduleId;
  final int eventTimestamp;
  final String memberId;
  final String type; // 'driver_start' | 'pickup' | 'destination'
  final double latitude;
  final double longitude;
  final int estimatedTime; // Unix timestamp in ms
  final bool isCompleted;

  RouteWaypoint({
    required this.id,
    required this.scheduleId,
    required this.eventTimestamp,
    required this.memberId,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.estimatedTime,
    this.isCompleted = false,
  });
}

class RouteOptimizerService {
  /// Solves TSP using a Greedy Nearest Neighbor heuristic using Haversine distance formula.
  List<RouteWaypoint> solveOptimalRoute({
    required String scheduleId,
    required int eventTimestamp,
    required String driverMemberId,
    required double driverLat,
    required double driverLng,
    required double destLat,
    required double destLng,
    required List<Map<String, dynamic>> riders, // [{ 'member_id': id, 'lat': lat, 'lng': lng }]
    required int targetArrivalTime, // Unix timestamp in ms
    double averageSpeedKph = 30.0,
  }) {
    List<Map<String, dynamic>> unvisited = List.from(riders);
    double currentLat = driverLat;
    double currentLng = driverLng;

    List<Map<String, dynamic>> orderedStops = [];

    // 1. Order stops by nearest neighbor
    while (unvisited.isNotEmpty) {
      int nearestIdx = 0;
      double minDistance = double.infinity;

      for (int i = 0; i < unvisited.length; i++) {
        double dist = calculateHaversineDistance(
          currentLat,
          currentLng,
          unvisited[i]['lat'] as double,
          unvisited[i]['lng'] as double,
        );
        if (dist < minDistance) {
          minDistance = dist;
          nearestIdx = i;
        }
      }

      var nextStop = unvisited.removeAt(nearestIdx);
      orderedStops.add(nextStop);
      currentLat = nextStop['lat'] as double;
      currentLng = nextStop['lng'] as double;
    }

    // 2. Build waypoint list and back-calculate arrival timing working backwards from destination
    // ...
    return [];
  }

  /// Calculates spherical distance between coordinates in kilometers using Haversine formula.
  static double calculateHaversineDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double r = 6371.0; // Earth's radius in kilometers
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _toRadians(double degree) => degree * pi / 180.0;
}
```

---

## 4. Real-Time Tracking, Dynamic ETAs, and Delay Alerts

While driving, `ActiveRouteScreen` updates GPS coordinates, updates estimated remaining times, and automatically dispatches room alerts (`org.carpool.alert`) if running behind schedule (>5 minutes). Delayed alerts queue locally in SQLite if offline and broadcast upon reconnection.
