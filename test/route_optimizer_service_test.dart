import 'package:flutter_test/flutter_test.dart';
import 'package:carpool_coordinator/services/route_optimizer_service.dart';

void main() {
  group('RouteOptimizerService Tests', () {
    test('Calculates Haversine distance correctly', () {
      final dist = RouteOptimizerService.haversineDistance(34.0194, -118.4912, 34.0415, -118.4520);
      expect(dist, greaterThan(0));
      expect(dist, lessThan(10)); // ~4.3 km apart
    });

    test('Solves optimal pickup route sequence', () {
      final driverHome = LocationCoord(latitude: 34.0194, longitude: -118.4912, memberId: 'driver_1');
      final destination = LocationCoord(latitude: 34.0415, longitude: -118.4520, memberId: 'dest');
      final riders = [
        LocationCoord(latitude: 34.0250, longitude: -118.4700, memberId: 'rider_1'),
        LocationCoord(latitude: 34.0300, longitude: -118.4600, memberId: 'rider_2'),
      ];

      final route = RouteOptimizerService.solveOptimalRoute(driverHome, destination, riders, 1698393600000);

      expect(route.length, equals(4)); // start + 2 pickups + dest
      expect(route.first.type, equals('driver_start'));
      expect(route.last.type, equals('destination'));
    });
  });
}
