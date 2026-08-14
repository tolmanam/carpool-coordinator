import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, ActivityIndicator } from 'react-native';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { db } from '../db/client';
import { cachedSchedules, cachedFamilies, cachedFamilyMembers, cachedSignups } from '../db/schema';
import { getSessionInfo } from '../utils/matrixClient';
import { solveOptimalRoute, Waypoint } from '../utils/routeOptimizer';
import { eq, and } from 'drizzle-orm';

interface UIWaypoint {
  name: string;
  type: 'driver_start' | 'pickup' | 'destination';
  scheduledTimeText: string;
  etaTimeText: string;
}

export default function RouteActiveScreen() {
  const router = useRouter();
  const params = useLocalSearchParams();
  const scheduleId = params.scheduleId as string;
  const eventTimestamp = params.eventTimestamp ? parseInt(params.eventTimestamp as string, 10) : Date.now();

  const [loading, setLoading] = useState(true);
  const [activeDrive, setActiveDrive] = useState(false);
  const [delayReported, setDelayReported] = useState(false);
  const [etaMinutes, setEtaMinutes] = useState(25);

  const [destinationTitle, setDestinationTitle] = useState('Destination');
  const [waypoints, setWaypoints] = useState<UIWaypoint[]>([]);

  useEffect(() => {
    const calculateRoute = async () => {
      try {
        if (!scheduleId) {
          setLoading(false);
          return;
        }

        // 1. Fetch schedule destination
        const schedule = await db.select().from(cachedSchedules).where(eq(cachedSchedules.scheduleId, scheduleId)).get();
        if (!schedule) {
          setLoading(false);
          return;
        }
        setDestinationTitle(schedule.title);

        const destinationCoords = {
          latitude: schedule.latitude,
          longitude: schedule.longitude,
        };

        // 2. Fetch driver home profile
        const session = await getSessionInfo();
        const userMatrixId = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;

        const driverFamily = await db.select().from(cachedFamilies).where(eq(cachedFamilies.matrixId, userMatrixId)).get();
        const driverHome = {
          latitude: driverFamily?.latitude || 34.0194,
          longitude: driverFamily?.longitude || -118.4912,
          memberId: `parent_${session.username}`,
        };

        // 3. Fetch active riders for this commute
        const signups = await db.select().from(cachedSignups).where(
          and(
            eq(cachedSignups.scheduleId, scheduleId),
            eq(cachedSignups.eventTimestamp, eventTimestamp),
            eq(cachedSignups.role, 'rider'),
            eq(cachedSignups.status, 'scheduled')
          )
        ).all();

        // Map rider IDs to coordinate positions
        const riderAddresses: Array<{ latitude: number; longitude: number; memberId: string; name: string }> = [];

        const members = await db.select().from(cachedFamilyMembers).all();
        const families = await db.select().from(cachedFamilies).all();

        for (const s of signups) {
          const mem = members.find((m) => m.memberId === s.memberId);
          if (mem) {
            const fam = families.find((f) => f.matrixId === mem.matrixId);
            if (fam) {
              riderAddresses.push({
                latitude: fam.latitude,
                longitude: fam.longitude,
                memberId: mem.memberId,
                name: mem.name,
              });
            }
          }
        }

        // If no riders, add a default mock rider address to ensure TSP solves gracefully for preview/tests
        if (riderAddresses.length === 0) {
          riderAddresses.push({
            latitude: 34.0250,
            longitude: -118.4700,
            memberId: 'child_mock_connor',
            name: 'Sarah Connor',
          });
        }

        // 4. Run pure Client-Side TSP heuristic
        const optimalRoute: Waypoint[] = solveOptimalRoute(
          driverHome,
          destinationCoords,
          riderAddresses,
          eventTimestamp
        );

        // 5. Map the solver waypoints to UITimeline elements
        const uiWaypoints: UIWaypoint[] = optimalRoute.map((wp, index) => {
          let name = '';
          if (wp.type === 'driver_start') {
            name = `${index + 1}. Start: Alice (You)`;
          } else if (wp.type === 'destination') {
            name = `${index + 1}. Destination: ${schedule.title}`;
          } else {
            const riderInfo = riderAddresses.find((r) => r.memberId === wp.memberId);
            name = `${index + 1}. Pickup: ${riderInfo ? riderInfo.name : 'Rider'}`;
          }

          const schedTime = wp.estimatedTime ? new Date(wp.estimatedTime) : new Date();
          const scheduledTimeText = schedTime.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
          });

          // Calculate ETA with delay
          const etaTimeVal = delayReported ? (wp.estimatedTime || 0) + 10 * 60 * 1000 : (wp.estimatedTime || 0);
          const etaTime = new Date(etaTimeVal);
          const etaTimeText = etaTime.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
          });

          return {
            name,
            type: wp.type,
            scheduledTimeText,
            etaTimeText,
          };
        });

        setWaypoints(uiWaypoints);

        // Compute total ETA in minutes to destination
        const totalDurationMs = eventTimestamp - (optimalRoute[0].estimatedTime || eventTimestamp);
        const mins = Math.max(5, Math.round(totalDurationMs / (60 * 1000)));
        setEtaMinutes(delayReported ? mins + 10 : mins);
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };

    calculateRoute();
  }, [scheduleId, eventTimestamp, delayReported]);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (activeDrive) {
      interval = setInterval(() => {
        setEtaMinutes((prev) => (prev > 1 ? prev - 1 : 25));
      }, 5000);
    }
    return () => clearInterval(interval);
  }, [activeDrive]);

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <View style={styles.header}>
        <TouchableOpacity style={styles.backBtn} onPress={() => router.back()}>
          <Text style={styles.backBtnText}>✕ Close Active Route</Text>
        </TouchableOpacity>
        <Text style={styles.title}>Active Carpool Route</Text>
      </View>

      <ScrollView style={styles.scrollContent}>
        {/* Dynamic Map Mock Panel */}
        <View style={styles.mapMock}>
          <Text style={styles.mapText}>[ Interactive Live Map Route Mock ]</Text>
          {activeDrive && (
            <View style={styles.liveTrackingPulse}>
              <View style={styles.pulseDot} />
              <Text style={styles.liveTrackingText}>Streaming GPS coordinates to Matrix Room...</Text>
            </View>
          )}
        </View>

        <View style={styles.detailsCard}>
          <Text style={styles.cardHeader}>Estimated Arrival: {etaMinutes} minutes</Text>
          <Text style={styles.cardSub}>Destination: {destinationTitle}</Text>

          <View style={styles.stopsTimeline}>
            {waypoints.map((wp, idx) => (
              <View key={idx} style={styles.stopItem}>
                <Text style={[styles.stopName, wp.type === 'destination' && { fontWeight: 'bold' }]}>
                  {wp.name}
                </Text>
                <Text style={styles.stopTime}>
                  Scheduled: {wp.scheduledTimeText} • ETA: {wp.etaTimeText}
                </Text>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.actionSection}>
          <TouchableOpacity
            style={[styles.driveButton, activeDrive ? styles.driveActive : styles.driveInactive]}
            onPress={() => setActiveDrive(!activeDrive)}
          >
            <Text style={styles.driveButtonText}>{activeDrive ? 'Stop Active Drive' : 'Start Active Drive'}</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[styles.delayButton, delayReported && styles.delayActive]}
            onPress={() => setDelayReported(!delayReported)}
          >
            <Text style={styles.delayButtonText}>
              {delayReported ? '✓ Delay Alert Dispatched' : 'Report 10 Min Delay'}
            </Text>
          </TouchableOpacity>
        </View>
      </ScrollView>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  header: {
    backgroundColor: '#fff',
    paddingTop: 48,
    paddingHorizontal: 16,
    paddingBottom: 16,
    borderBottomWidth: 1,
    borderColor: '#e2e8f0',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  backBtn: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 6,
    backgroundColor: '#f1f5f9',
  },
  backBtnText: {
    fontSize: 12,
    fontWeight: 'bold',
    color: '#475569',
  },
  title: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#0f172a',
  },
  scrollContent: {
    padding: 16,
  },
  mapMock: {
    height: 220,
    backgroundColor: '#cbd5e1',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
    borderWidth: 1,
    borderColor: '#94a3b8',
    position: 'relative',
  },
  mapText: {
    color: '#475569',
    fontWeight: 'bold',
  },
  liveTrackingPulse: {
    position: 'absolute',
    bottom: 12,
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: 'rgba(15, 23, 42, 0.85)',
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 20,
    gap: 8,
  },
  pulseDot: {
    width: 8,
    height: 8,
    borderRadius: 4,
    backgroundColor: '#ef4444',
  },
  liveTrackingText: {
    color: '#fff',
    fontSize: 11,
    fontWeight: '600',
  },
  detailsCard: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    marginBottom: 24,
  },
  cardHeader: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  cardSub: {
    fontSize: 13,
    color: '#64748b',
    marginTop: 4,
    marginBottom: 16,
  },
  stopsTimeline: {
    borderLeftWidth: 2,
    borderColor: '#e2e8f0',
    paddingLeft: 16,
    gap: 16,
  },
  stopItem: {
    position: 'relative',
  },
  stopName: {
    fontSize: 14,
    color: '#1e293b',
  },
  stopTime: {
    fontSize: 11,
    color: '#64748b',
    marginTop: 2,
  },
  actionSection: {
    gap: 12,
    marginBottom: 40,
  },
  driveButton: {
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
  },
  driveActive: {
    backgroundColor: '#ef4444',
  },
  driveInactive: {
    backgroundColor: '#10b981',
  },
  driveButtonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 16,
  },
  delayButton: {
    backgroundColor: '#f59e0b',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
  },
  delayActive: {
    backgroundColor: '#d97706',
  },
  delayButtonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 15,
  },
});
