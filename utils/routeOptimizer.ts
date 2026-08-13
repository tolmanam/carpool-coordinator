export interface Waypoint {
  memberId?: string; // Optional, empty for target Destination point
  type: 'driver_start' | 'pickup' | 'destination';
  latitude: number;
  longitude: number;
  estimatedTime?: number;
}

/**
 * Calculates straight line spherical distance between coordinates.
 */
export function calculateHaversineDistance(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371; // Earth's radius in kilometers
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

/**
 * Solves TSP using a Greedy Nearest Neighbor heuristic.
 * Perfect for typical carpools (<10 addresses) to avoid battery drain or paid APIs.
 */
export function solveOptimalRoute(
  driverHome: { latitude: number; longitude: number; memberId: string },
  destination: { latitude: number; longitude: number },
  riderAddresses: Array<{ latitude: number; longitude: number; memberId: string }>,
  targetArrivalTime: number, // Unix Timestamp
  averageSpeedKph: number = 30 // Typical urban driving velocity
): Waypoint[] {
  let unvisited = [...riderAddresses];
  let currentLoc = { ...driverHome };
  const route: Waypoint[] = [
    {
      memberId: driverHome.memberId,
      type: 'driver_start',
      latitude: driverHome.latitude,
      longitude: driverHome.longitude,
    },
  ];

  // 1. Solve order by finding nearest neighbor incrementally
  while (unvisited.length > 0) {
    let nearestIdx = 0;
    let minDistance = Infinity;

    for (let i = 0; i < unvisited.length; i++) {
      const dist = calculateHaversineDistance(
        currentLoc.latitude,
        currentLoc.longitude,
        unvisited[i].latitude,
        unvisited[i].longitude
      );
      if (dist < minDistance) {
        minDistance = dist;
        nearestIdx = i;
      }
    }

    const nextStop = unvisited.splice(nearestIdx, 1)[0];
    route.push({
      memberId: nextStop.memberId,
      type: 'pickup',
      latitude: nextStop.latitude,
      longitude: nextStop.longitude,
    });
    currentLoc = nextStop;
  }

  // 2. Add final target destination
  route.push({
    type: 'destination',
    latitude: destination.latitude,
    longitude: destination.longitude,
  });

  // 3. Back-calculate optimal pick-up arrival timing working backwards from Target Destination
  let currentTimestamp = targetArrivalTime;

  for (let i = route.length - 1; i > 0; i--) {
    const endPoint = route[i];
    const startPoint = route[i - 1];

    const distanceKm = calculateHaversineDistance(
      startPoint.latitude,
      startPoint.longitude,
      endPoint.latitude,
      endPoint.longitude
    );

    const travelTimeMs = (distanceKm / averageSpeedKph) * 60 * 60 * 1000;
    currentTimestamp = currentTimestamp - travelTimeMs;

    startPoint.estimatedTime = Math.round(currentTimestamp);
  }

  route[route.length - 1].estimatedTime = targetArrivalTime;

  return route;
}
