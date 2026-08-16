import 'dart:math';
import '../models/models.dart';

class LocationCoord {
  final double latitude;
  final double longitude;
  final String memberId;

  LocationCoord({
    required this.latitude,
    required this.longitude,
    required this.memberId,
  });
}

class RouteOptimizerService {
  static double haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0; // Earth's radius in kilometers
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) * cos(_degreesToRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return r * c;
  }

  static double _degreesToRadians(double degrees) {
    return degrees * (pi / 180.0);
  }

  static List<RouteWaypoint> solveOptimalRoute(
    LocationCoord driverHome,
    LocationCoord destination,
    List<LocationCoord> riders,
    int eventTimestamp,
  ) {
    final List<RouteWaypoint> route = [];

    // 1. Driver Start
    route.add(RouteWaypoint(
      memberId: driverHome.memberId,
      type: 'driver_start',
      latitude: driverHome.latitude,
      longitude: driverHome.longitude,
      estimatedTime: eventTimestamp - (30 * 60 * 1000), // 30 mins before
    ));

    // 2. Greedy Nearest Neighbor for Pickups
    final List<LocationCoord> unvisited = List.from(riders);
    var currentLat = driverHome.latitude;
    var currentLon = driverHome.longitude;
    var currentTime = eventTimestamp - (30 * 60 * 1000);

    while (unvisited.isNotEmpty) {
      unvisited.sort((a, b) {
        final distA = haversineDistance(currentLat, currentLon, a.latitude, a.longitude);
        final distB = haversineDistance(currentLat, currentLon, b.latitude, b.longitude);
        return distA.compareTo(distB);
      });

      final nextStop = unvisited.removeAt(0);
      final dist = haversineDistance(currentLat, currentLon, nextStop.latitude, nextStop.longitude);
      final travelMins = max(5, (dist / 0.5).round()); // Assume ~30km/h avg speed

      currentTime += travelMins * 60 * 1000;

      route.add(RouteWaypoint(
        memberId: nextStop.memberId,
        type: 'pickup',
        latitude: nextStop.latitude,
        longitude: nextStop.longitude,
        estimatedTime: currentTime,
      ));

      currentLat = nextStop.latitude;
      currentLon = nextStop.longitude;
    }

    // 3. Destination
    route.add(RouteWaypoint(
      memberId: destination.memberId,
      type: 'destination',
      latitude: destination.latitude,
      longitude: destination.longitude,
      estimatedTime: eventTimestamp,
    ));

    return route;
  }
}
