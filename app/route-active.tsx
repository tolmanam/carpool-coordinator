import React, { useState, useEffect } from 'react';
import { StyleSheet, View, ScrollView } from 'react-native';
import {
  Text,
  Card,
  Button,
  ActivityIndicator,
  Banner,
  useTheme,
  Surface,
  Divider,
  Icon,
} from 'react-native-paper';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { db } from '../db/client';
import { cachedSchedules, cachedFamilies, cachedFamilyMembers, cachedSignups } from '../db/schema';
import { getSessionInfo, processActiveGpsTick, mockMatrixCloud } from '../utils/matrixClient';
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
  const theme = useTheme();
  const params = useLocalSearchParams();
  const scheduleId = params.scheduleId as string;
  const eventTimestamp = params.eventTimestamp ? parseInt(params.eventTimestamp as string, 10) : Date.now();

  const [loading, setLoading] = useState(true);
  const [activeDrive, setActiveDrive] = useState(false);
  const [delayReported, setDelayReported] = useState(false);
  const [etaMinutes, setEtaMinutes] = useState(25);

  const [destinationTitle, setDestinationTitle] = useState('Destination');
  const [waypoints, setWaypoints] = useState<UIWaypoint[]>([]);
  const [activeAlert, setActiveAlert] = useState<string | null>(null);

  useEffect(() => {
    if (activeDrive) {
      const simulateGpsTick = async () => {
        const currentLoc = { latitude: 34.0194, longitude: -118.4912 };

        const simulatedWaypoints: Waypoint[] = waypoints.map((wp) => {
          const orig = Date.now() + 10 * 60 * 1000;
          const est = delayReported ? orig + 10 * 60 * 1000 : orig;
          return {
            type: wp.type === 'driver_start' ? 'driver_start' : (wp.type === 'destination' ? 'destination' : 'pickup'),
            latitude: currentLoc.latitude,
            longitude: currentLoc.longitude,
            originalScheduledTime: orig,
            estimatedTime: est,
          };
        });

        await processActiveGpsTick(currentLoc, simulatedWaypoints, scheduleId, eventTimestamp);
      };

      simulateGpsTick();
    }
  }, [activeDrive, delayReported, scheduleId, eventTimestamp, waypoints]);

  useEffect(() => {
    const checkAlerts = () => {
      const roomMsgs = mockMatrixCloud.messages[scheduleId] || [];
      const latestAlert = [...roomMsgs]
        .reverse()
        .find(msg => msg.type === 'org.carpool.alert' && msg.content?.schedule_id === scheduleId);
      if (latestAlert) {
        setActiveAlert(latestAlert.content.message);
      } else {
        setActiveAlert(null);
      }
    };

    checkAlerts();
    const interval = setInterval(checkAlerts, 2000);
    return () => clearInterval(interval);
  }, [scheduleId, delayReported]);

  useEffect(() => {
    if (!delayReported && mockMatrixCloud.messages[scheduleId]) {
      mockMatrixCloud.messages[scheduleId] = mockMatrixCloud.messages[scheduleId].filter(
        msg => msg.type !== 'org.carpool.alert'
      );
      setActiveAlert(null);
    }
  }, [delayReported, scheduleId]);

  useEffect(() => {
    const calculateRoute = async () => {
      try {
        if (!scheduleId) {
          setLoading(false);
          return;
        }

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

        const session = await getSessionInfo();
        const userMatrixId = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;

        const driverFamily = await db.select().from(cachedFamilies).where(eq(cachedFamilies.matrixId, userMatrixId)).get();
        const driverHome = {
          latitude: driverFamily?.latitude || 34.0194,
          longitude: driverFamily?.longitude || -118.4912,
          memberId: `parent_${session.username}`,
        };

        const signups = await db.select().from(cachedSignups).where(
          and(
            eq(cachedSignups.scheduleId, scheduleId),
            eq(cachedSignups.eventTimestamp, eventTimestamp),
            eq(cachedSignups.role, 'rider'),
            eq(cachedSignups.status, 'scheduled')
          )
        ).all();

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

        if (riderAddresses.length === 0) {
          riderAddresses.push({
            latitude: 34.0250,
            longitude: -118.4700,
            memberId: 'child_mock_connor',
            name: 'Sarah Connor',
          });
        }

        const optimalRoute: Waypoint[] = solveOptimalRoute(
          driverHome,
          destinationCoords,
          riderAddresses,
          eventTimestamp
        );

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
        <ActivityIndicator size="large" animating={true} color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Surface style={styles.header} elevation={1}>
        <Button
          mode="contained-tonal"
          onPress={() => router.back()}
          icon="close"
          compact
        >
          Close
        </Button>
        <Text variant="titleMedium" style={styles.title}>
          Active Carpool Route
        </Text>
      </Surface>

      <ScrollView contentContainerStyle={styles.scrollContent}>
        {/* Dynamic Map Mock Surface */}
        <Surface style={styles.mapMock} elevation={2}>
          <Text variant="titleSmall" style={styles.mapText}>
            [ Interactive Live Map Route ]
          </Text>
          {activeDrive && (
            <View style={styles.liveTrackingPulse}>
              <View style={styles.pulseDot} />
              <Text variant="bodySmall" style={styles.liveTrackingText}>
                Streaming GPS coordinates to Matrix Room...
              </Text>
            </View>
          )}
        </Surface>

        {activeAlert && (
          <Banner
            visible={true}
            icon="alert"
            style={styles.alertBanner}
          >
            {activeAlert}
          </Banner>
        )}

        <Card style={styles.detailsCard} mode="elevated">
          <Card.Content>
            <Text variant="titleLarge" style={styles.cardHeader}>
              Estimated Arrival: {etaMinutes} mins
            </Text>
            <Text variant="bodyMedium" style={styles.cardSub}>
              Destination: {destinationTitle}
            </Text>

            <Divider style={styles.divider} />

            <View style={styles.stopsTimeline}>
              {waypoints.map((wp, idx) => (
                <View key={idx} style={styles.stopItem}>
                  <View style={styles.stopHeader}>
                    <Icon
                      source={
                        wp.type === 'driver_start'
                          ? 'car'
                          : wp.type === 'destination'
                          ? 'flag-checkered'
                          : 'account-child'
                      }
                      size={18}
                      color={theme.colors.primary}
                    />
                    <Text
                      variant="bodyMedium"
                      style={[styles.stopName, wp.type === 'destination' && { fontWeight: 'bold' }]}
                    >
                      {wp.name}
                    </Text>
                  </View>
                  <Text variant="bodySmall" style={styles.stopTime}>
                    Scheduled: {wp.scheduledTimeText} • ETA: {wp.etaTimeText}
                  </Text>
                </View>
              ))}
            </View>
          </Card.Content>
        </Card>

        <View style={styles.actionSection}>
          <Button
            mode="contained"
            buttonColor={activeDrive ? '#ef4444' : '#10b981'}
            onPress={() => setActiveDrive(!activeDrive)}
            icon={activeDrive ? 'stop' : 'play'}
            style={styles.actionBtn}
            contentStyle={styles.btnContent}
          >
            {activeDrive ? 'Stop Active Drive' : 'Start Active Drive'}
          </Button>

          <Button
            mode="contained"
            buttonColor={delayReported ? '#d97706' : '#f59e0b'}
            onPress={() => setDelayReported(!delayReported)}
            icon={delayReported ? 'check-circle' : 'clock-alert'}
            style={styles.actionBtn}
            contentStyle={styles.btnContent}
          >
            {delayReported ? 'Delay Alert Dispatched' : 'Report 10 Min Delay'}
          </Button>
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
    paddingTop: 48,
    paddingHorizontal: 16,
    paddingBottom: 12,
    backgroundColor: '#ffffff',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
  },
  title: {
    fontWeight: 'bold',
    color: '#0f172a',
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 32,
  },
  mapMock: {
    height: 200,
    backgroundColor: '#cbd5e1',
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
    position: 'relative',
  },
  mapText: {
    color: '#334155',
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
    color: '#ffffff',
    fontWeight: '600',
  },
  alertBanner: {
    backgroundColor: '#fffbeb',
    borderRadius: 8,
    marginBottom: 16,
  },
  detailsCard: {
    backgroundColor: '#ffffff',
    borderRadius: 12,
    marginBottom: 20,
  },
  cardHeader: {
    fontWeight: 'bold',
    color: '#1e293b',
  },
  cardSub: {
    color: '#64748b',
    marginTop: 2,
  },
  divider: {
    marginVertical: 12,
  },
  stopsTimeline: {
    borderLeftWidth: 2,
    borderColor: '#cbd5e1',
    paddingLeft: 12,
    gap: 14,
  },
  stopItem: {},
  stopHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  stopName: {
    color: '#1e293b',
  },
  stopTime: {
    color: '#64748b',
    marginTop: 2,
    marginLeft: 26,
  },
  actionSection: {
    gap: 12,
  },
  actionBtn: {
    borderRadius: 8,
  },
  btnContent: {
    paddingVertical: 6,
  },
});
