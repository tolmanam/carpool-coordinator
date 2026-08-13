import { solveOptimalRoute, calculateHaversineDistance, Waypoint } from '../routeOptimizer';

describe('Route Optimizer - TSP Solver', () => {
  const driverHome = { latitude: 37.7749, longitude: -122.4194, memberId: 'driver1' }; // San Francisco
  const destination = { latitude: 37.8044, longitude: -122.4018 }; // Fisherman's Wharf, SF (approx 4.5km away)
  const targetArrivalTime = Date.UTC(2026, 7, 15, 17, 0, 0); // 5:00 PM UTC

  test('calculateHaversineDistance computes correct approximate distance', () => {
    // SF to Oakland is approx 13-15km depending on exact points
    const lat1 = 37.7749;
    const lon1 = -122.4194;
    const lat2 = 37.8044;
    const lon2 = -122.2711; // Oakland
    const distance = calculateHaversineDistance(lat1, lon1, lat2, lon2);
    expect(distance).toBeGreaterThan(11);
    expect(distance).toBeLessThan(16);
  });

  test('solveOptimalRoute with no riders goes directly to destination', () => {
    const route = solveOptimalRoute(driverHome, destination, [], targetArrivalTime, 30);

    expect(route).toHaveLength(2);
    expect(route[0].type).toBe('driver_start');
    expect(route[0].memberId).toBe('driver1');
    expect(route[1].type).toBe('destination');
    expect(route[1].estimatedTime).toBe(targetArrivalTime);

    // Start time should be earlier than arrival time
    expect(route[0].estimatedTime).toBeLessThan(targetArrivalTime);

    // Expected travel time calculation
    const distance = calculateHaversineDistance(
      driverHome.latitude,
      driverHome.longitude,
      destination.latitude,
      destination.longitude
    );
    const expectedTravelTimeMs = (distance / 30) * 60 * 60 * 1000;
    const expectedStartTime = targetArrivalTime - expectedTravelTimeMs;
    expect(route[0].estimatedTime).toBeCloseTo(expectedStartTime, -1);
  });

  test('solveOptimalRoute sorts multiple riders using nearest-neighbor heuristic', () => {
    // SF coordinates:
    // Driver: 37.7749, -122.4194 (SOMA)
    // Rider 1 (Close to SOMA): 37.7794, -122.4184 (Civic Center)
    // Rider 2 (Further away): 37.7894, -122.4014 (Union Square)
    // Destination: 37.8044, -122.4018 (Fisherman's Wharf)
    const rider1 = { latitude: 37.7794, longitude: -122.4184, memberId: 'rider1' };
    const rider2 = { latitude: 37.7894, longitude: -122.4014, memberId: 'rider2' };
    const riders = [rider2, rider1]; // Feed them out of order

    const route = solveOptimalRoute(driverHome, destination, riders, targetArrivalTime, 30);

    // Expected order: Driver -> Rider 1 -> Rider 2 -> Destination
    expect(route).toHaveLength(4);
    expect(route[0].type).toBe('driver_start');
    expect(route[0].memberId).toBe('driver1');

    expect(route[1].type).toBe('pickup');
    expect(route[1].memberId).toBe('rider1'); // Rider 1 is closer to driver than Rider 2

    expect(route[2].type).toBe('pickup');
    expect(route[2].memberId).toBe('rider2');

    expect(route[3].type).toBe('destination');
    expect(route[3].estimatedTime).toBe(targetArrivalTime);

    // Verify times are sequential and realistic
    expect(route[0].estimatedTime).toBeLessThan(route[1].estimatedTime!);
    expect(route[1].estimatedTime!).toBeLessThan(route[2].estimatedTime!);
    expect(route[2].estimatedTime!).toBeLessThan(route[3].estimatedTime!);
  });

  test('solveOptimalRoute handles averageSpeedKph speed variance', () => {
    const rider1 = { latitude: 37.7794, longitude: -122.4184, memberId: 'rider1' };

    const slowRoute = solveOptimalRoute(driverHome, destination, [rider1], targetArrivalTime, 10); // 10 kph
    const fastRoute = solveOptimalRoute(driverHome, destination, [rider1], targetArrivalTime, 60); // 60 kph

    // The start time for slow route must be much earlier than the fast route
    expect(slowRoute[0].estimatedTime).toBeLessThan(fastRoute[0].estimatedTime!);
  });
});
