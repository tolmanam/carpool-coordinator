import React, { useState, useEffect } from 'react';
import { StyleSheet, View, ScrollView } from 'react-native';
import {
  Text,
  Card,
  Button,
  Chip,
  ActivityIndicator,
  Banner,
  useTheme,
  Divider,
  Icon,
} from 'react-native-paper';
import { useRouter } from 'expo-router';
import { db } from '../../db/client';
import { localIcalEvents, cachedSignups, cachedFamilyMembers, cachedSchedules } from '../../db/schema';
import { getSessionInfo, registerSignup, removeSignup, syncIcalFeed } from '../../utils/matrixClient';
import { eq } from 'drizzle-orm';

interface UIOccurrence {
  id: string;
  scheduleId: string;
  title: string;
  timeText: string;
  timestamp: number;
  driverName: string | null;
  ridersNames: string[];
  userRole: 'rider' | 'driver' | null;
  riderMemberId: string;
  driverMemberId: string;
}

export default function ScheduleScreen() {
  const router = useRouter();
  const theme = useTheme();

  const [loading, setLoading] = useState(true);
  const [events, setEvents] = useState<UIOccurrence[]>([]);
  const [username, setUsername] = useState('');
  const [scheduleId, setScheduleId] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const session = await getSessionInfo();
      setUsername(session.username);

      let allSchedules = await db.select().from(cachedSchedules).all();
      if (allSchedules.length === 0) {
        await db.insert(cachedSchedules).values({
          scheduleId: 'sched_soccer_practice',
          title: 'Westside Soccer Family Club',
          icalFeedUrl: '',
          latitude: 34.0415,
          longitude: -118.4520,
          addressText: 'Clover Park Field 2',
        });
        allSchedules = await db.select().from(cachedSchedules).all();
      }

      const activeScheduleId = allSchedules[0].scheduleId;
      setScheduleId(activeScheduleId);

      let allIcalEvents = await db.select().from(localIcalEvents).where(eq(localIcalEvents.scheduleId, activeScheduleId)).all();
      if (allIcalEvents.length === 0) {
        await syncIcalFeed(activeScheduleId);
        allIcalEvents = await db.select().from(localIcalEvents).where(eq(localIcalEvents.scheduleId, activeScheduleId)).all();
      }

      const allMembers = await db.select().from(cachedFamilyMembers).all();
      const parentMember = allMembers.find((m) => m.role === 'parent');
      const childMember = allMembers.find((m) => m.role === 'child');

      const parentId = parentMember?.memberId || `parent_${session.username}`;
      const childId = childMember?.memberId || `child_${session.username}`;

      const allSignups = await db.select().from(cachedSignups).where(eq(cachedSignups.scheduleId, activeScheduleId)).all();

      const mappedEvents: UIOccurrence[] = allIcalEvents.map((evt) => {
        const start = new Date(evt.startTime);
        const end = new Date(evt.endTime);

        const timeText = `${start.toLocaleDateString('en-US', {
          weekday: 'short',
          month: 'short',
          day: 'numeric',
        })}, ${start.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
        })} - ${end.toLocaleTimeString('en-US', {
          hour: '2-digit',
          minute: '2-digit',
        })}`;

        const matchedSignups = allSignups.filter((s) => s.eventTimestamp === evt.startTime);

        const driverSignup = matchedSignups.find((s) => s.role === 'driver' && s.status === 'scheduled');
        let driverName = null;
        if (driverSignup) {
          if (driverSignup.memberId === parentId) {
            driverName = 'You';
          } else {
            const m = allMembers.find((mem) => mem.memberId === driverSignup.memberId);
            driverName = m ? m.name : 'Unknown Driver';
          }
        }

        const riderSignups = matchedSignups.filter((s) => s.role === 'rider' && s.status === 'scheduled');
        const ridersNames = riderSignups.map((rs) => {
          if (rs.memberId === childId) {
            return 'You';
          }
          const m = allMembers.find((mem) => mem.memberId === rs.memberId);
          return m ? m.name : 'Unknown Rider';
        });

        let userRole: 'rider' | 'driver' | null = null;
        if (matchedSignups.some((s) => s.memberId === childId && s.role === 'rider' && s.status === 'scheduled')) {
          userRole = 'rider';
        } else if (matchedSignups.some((s) => s.memberId === parentId && s.role === 'driver' && s.status === 'scheduled')) {
          userRole = 'driver';
        }

        return {
          id: evt.id,
          scheduleId: evt.scheduleId,
          title: evt.title,
          timeText,
          timestamp: evt.startTime,
          driverName,
          ridersNames,
          userRole,
          riderMemberId: childId,
          driverMemberId: parentId,
        };
      });

      mappedEvents.sort((a, b) => a.timestamp - b.timestamp);
      setEvents(mappedEvents);
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const toggleRide = async (event: UIOccurrence) => {
    setEvents((prev) =>
      prev.map((e) => {
        if (e.id !== event.id) return e;
        const alreadySignedUp = e.userRole === 'rider';
        return {
          ...e,
          userRole: alreadySignedUp ? null : 'rider',
          ridersNames: alreadySignedUp
            ? e.ridersNames.filter((r) => r !== 'You')
            : [...e.ridersNames.filter((r) => r !== 'You'), 'You'],
          driverName: e.driverName === 'You' ? null : e.driverName,
        };
      })
    );

    if (event.userRole === 'rider') {
      await removeSignup(event.scheduleId, event.timestamp, event.riderMemberId);
    } else {
      await removeSignup(event.scheduleId, event.timestamp, event.driverMemberId);
      await registerSignup({
        scheduleId: event.scheduleId,
        eventTimestamp: event.timestamp,
        memberId: event.riderMemberId,
        role: 'rider',
        status: 'scheduled',
      });
    }
    await loadData();
  };

  const toggleDrive = async (event: UIOccurrence) => {
    setEvents((prev) =>
      prev.map((e) => {
        if (e.id !== event.id) return e;
        const alreadyDriving = e.userRole === 'driver';
        return {
          ...e,
          userRole: alreadyDriving ? null : 'driver',
          driverName: alreadyDriving ? null : 'You',
          ridersNames: e.ridersNames.filter((r) => r !== 'You'),
        };
      })
    );

    if (event.userRole === 'driver') {
      await removeSignup(event.scheduleId, event.timestamp, event.driverMemberId);
    } else {
      await removeSignup(event.scheduleId, event.timestamp, event.riderMemberId);
      await registerSignup({
        scheduleId: event.scheduleId,
        eventTimestamp: event.timestamp,
        memberId: event.driverMemberId,
        role: 'driver',
        status: 'scheduled',
      });
    }
    await loadData();
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" animating={true} color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <Banner
        visible={true}
        icon="check-circle-outline"
        style={styles.banner}
      >
        Local Database Synced Offline
      </Banner>

      <Text variant="titleLarge" style={styles.sectionHeader}>
        Upcoming Commutes
      </Text>

      {events.map((event) => (
        <Card key={event.id} style={styles.card} mode="elevated">
          <Card.Content>
            <Text variant="titleMedium" style={styles.eventTitle}>
              {event.title}
            </Text>
            <Text variant="bodyMedium" style={styles.eventTime}>
              {event.timeText}
            </Text>

            <Divider style={styles.divider} />

            <View style={styles.participantSection}>
              <View style={styles.infoRow}>
                <Icon source="car" size={18} color={theme.colors.primary} />
                <Text variant="bodyMedium" style={styles.subLabel}>
                  Driver:{' '}
                  <Text variant="bodyMedium" style={styles.val}>
                    {event.driverName || 'No driver assigned yet'}
                  </Text>
                </Text>
              </View>

              <View style={styles.infoRow}>
                <Icon source="account-group" size={18} color={theme.colors.secondary} />
                <Text variant="bodyMedium" style={styles.subLabel}>
                  Riders:{' '}
                  <Text variant="bodyMedium" style={styles.val}>
                    {event.ridersNames.length > 0 ? event.ridersNames.join(', ') : 'No riders registered'}
                  </Text>
                </Text>
              </View>
            </View>

            <View style={styles.chipRow}>
              <Chip
                selected={event.userRole === 'rider'}
                onPress={() => toggleRide(event)}
                icon={event.userRole === 'rider' ? 'check' : 'human-child'}
                mode="outlined"
                style={styles.chip}
              >
                {event.userRole === 'rider' ? 'Registered Ride' : 'Ride'}
              </Chip>

              <Chip
                selected={event.userRole === 'driver'}
                onPress={() => toggleDrive(event)}
                icon={event.userRole === 'driver' ? 'check' : 'steering'}
                mode="outlined"
                style={styles.chip}
              >
                {event.userRole === 'driver' ? 'Driving Route' : 'Drive'}
              </Chip>
            </View>

            {event.userRole === 'driver' && (
              <Button
                mode="contained"
                buttonColor="#10b981"
                icon="navigation"
                style={styles.startDriveBtn}
                onPress={() =>
                  router.push({
                    pathname: '/route-active',
                    params: { scheduleId: event.scheduleId, eventTimestamp: event.timestamp.toString() },
                  })
                }
              >
                Start Driving Route
              </Button>
            )}
          </Card.Content>
        </Card>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
  },
  contentContainer: {
    padding: 16,
    paddingBottom: 32,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  banner: {
    backgroundColor: '#ecfdf5',
    borderRadius: 8,
    marginBottom: 16,
  },
  sectionHeader: {
    fontWeight: 'bold',
    color: '#0f172a',
    marginBottom: 12,
  },
  card: {
    marginBottom: 16,
    backgroundColor: '#ffffff',
    borderRadius: 12,
  },
  eventTitle: {
    fontWeight: 'bold',
    color: '#1e293b',
  },
  eventTime: {
    color: '#64748b',
    marginTop: 2,
  },
  divider: {
    marginVertical: 12,
  },
  participantSection: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    padding: 12,
    gap: 8,
    marginBottom: 12,
  },
  infoRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  subLabel: {
    fontWeight: '600',
    color: '#475569',
  },
  val: {
    fontWeight: 'normal',
    color: '#1e293b',
  },
  chipRow: {
    flexDirection: 'row',
    gap: 8,
  },
  chip: {
    flex: 1,
  },
  startDriveBtn: {
    marginTop: 12,
    borderRadius: 8,
  },
});
