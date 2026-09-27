import 'dart:convert';
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
  /// Resolves the pickup location for a family member for a given event timestamp,
  /// factoring in co-parenting custody schedules if configured.
  static LocationCoord resolveRiderLocation({
    required FamilyMember member,
    required Family family,
    required int eventTimestamp,
  }) {
    double lat = family.latitude;
    double lon = family.longitude;

    if (member.custodyScheduleJson.isNotEmpty) {
      try {
        final decoded = jsonDecode(member.custodyScheduleJson) as Map<String, dynamic>;
        final eventDate = DateTime.fromMillisecondsSinceEpoch(eventTimestamp);
        final dayStr = eventDate.weekday.toString(); // 1 = Monday, 7 = Sunday
        if (decoded.containsKey(dayStr)) {
          final dayData = decoded[dayStr] as Map<String, dynamic>;
          if (dayData.containsKey('latitude') && dayData.containsKey('longitude')) {
            lat = (dayData['latitude'] as num).toDouble();
            lon = (dayData['longitude'] as num).toDouble();
          }
        }
      } catch (_) {}
    }

    return LocationCoord(
      latitude: lat,
      longitude: lon,
      memberId: member.memberId,
    );
  }
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

  /// Calculates total travel distance in km for a sequence of stops starting at driver home,
  /// visiting riders, and ending at destination.
  static double calculateTotalDistance(
    LocationCoord driverHome,
    LocationCoord destination,
    List<LocationCoord> riders,
  ) {
    if (riders.isEmpty) {
      return haversineDistance(
        driverHome.latitude,
        driverHome.longitude,
        destination.latitude,
        destination.longitude,
      );
    }
    final waypoints = solveOptimalRoute(driverHome, destination, riders, DateTime.now().millisecondsSinceEpoch);
    double totalDist = 0.0;
    for (int i = 0; i < waypoints.length - 1; i++) {
      totalDist += haversineDistance(
        waypoints[i].latitude,
        waypoints[i].longitude,
        waypoints[i + 1].latitude,
        waypoints[i + 1].longitude,
      );
    }
    return totalDist;
  }

  /// Evaluates the detour impact (distance delta and estimated time delta in minutes)
  /// of adding a new candidate rider to an existing route.
  static Map<String, dynamic> calculateDetourImpact({
    required LocationCoord driverHome,
    required LocationCoord destination,
    required List<LocationCoord> existingRiders,
    required LocationCoord candidateRider,
  }) {
    final directDist = calculateTotalDistance(driverHome, destination, existingRiders);
    final withCandidateRiders = List<LocationCoord>.from(existingRiders)..add(candidateRider);
    final detourDist = calculateTotalDistance(driverHome, destination, withCandidateRiders);

    final distanceDeltaKm = max(0.0, detourDist - directDist);
    // Assuming avg speed 30 km/h -> 1 km takes 2 mins
    final timeDeltaMinutes = (distanceDeltaKm * 2.0).round();

    return {
      'direct_distance_km': directDist,
      'detour_distance_km': detourDist,
      'distance_delta_km': distanceDeltaKm,
      'time_delta_minutes': timeDeltaMinutes,
    };
  }

  /// Checks whether adding a candidate rider exceeds the driver's max detour threshold in minutes.
  static bool isWithinDetourThreshold({
    required LocationCoord driverHome,
    required LocationCoord destination,
    required List<LocationCoord> existingRiders,
    required LocationCoord candidateRider,
    required int maxDetourMinutes,
  }) {
    final impact = calculateDetourImpact(
      driverHome: driverHome,
      destination: destination,
      existingRiders: existingRiders,
      candidateRider: candidateRider,
    );
    final timeDelta = impact['time_delta_minutes'] as int;
    return timeDelta <= maxDetourMinutes;
  }
}
