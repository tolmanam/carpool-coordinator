import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { db } from '../../db/client';
import { localIcalEvents, cachedSignups, cachedFamilyMembers, cachedSchedules } from '../../db/schema';
import { getSessionInfo, registerSignup, removeSignup, syncIcalFeed } from '../../utils/matrixClient';
import { eq, and } from 'drizzle-orm';

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
  const [loading, setLoading] = useState(true);
  const [events, setEvents] = useState<UIOccurrence[]>([]);
  const [username, setUsername] = useState('');
  const [scheduleId, setScheduleId] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const session = await getSessionInfo();
      setUsername(session.username);

      // Find first schedule or seed one if empty so there is always a valid demo schedule
      let allSchedules = await db.select().from(cachedSchedules).all();
      if (allSchedules.length === 0) {
        // Seed default schedule/circle
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

      // Trigger standard local iCal sync so there are some events to display
      let allIcalEvents = await db.select().from(localIcalEvents).where(eq(localIcalEvents.scheduleId, activeScheduleId)).all();
      if (allIcalEvents.length === 0) {
        await syncIcalFeed(activeScheduleId);
        allIcalEvents = await db.select().from(localIcalEvents).where(eq(localIcalEvents.scheduleId, activeScheduleId)).all();
      }

      // Query family members to map IDs to actual names
      const allMembers = await db.select().from(cachedFamilyMembers).all();
      const parentMember = allMembers.find((m) => m.role === 'parent');
      const childMember = allMembers.find((m) => m.role === 'child');

      const parentId = parentMember?.memberId || `parent_${session.username}`;
      const childId = childMember?.memberId || `child_${session.username}`;

      // Query all signups for this schedule
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

        // Filter signups matching this occurrence timestamp
        const matchedSignups = allSignups.filter((s) => s.eventTimestamp === evt.startTime);

        // Find driver
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

        // Find riders
        const riderSignups = matchedSignups.filter((s) => s.role === 'rider' && s.status === 'scheduled');
        const ridersNames = riderSignups.map((rs) => {
          if (rs.memberId === childId) {
            return 'You';
          }
          const m = allMembers.find((mem) => mem.memberId === rs.memberId);
          return m ? m.name : 'Unknown Rider';
        });

        // Determine logged in user sign up role
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

      // Sort chronological
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
    // Optimistic local state update
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

    // Persist to local database
    if (event.userRole === 'rider') {
      await removeSignup(event.scheduleId, event.timestamp, event.riderMemberId);
    } else {
      // Remove driving if any, then register ride
      await removeSignup(event.scheduleId, event.timestamp, event.driverMemberId);
      await registerSignup({
        scheduleId: event.scheduleId,
        eventTimestamp: event.timestamp,
        memberId: event.riderMemberId,
        role: 'rider',
        status: 'scheduled',
      });
    }
    // Reload full database data
    await loadData();
  };

  const toggleDrive = async (event: UIOccurrence) => {
    // Optimistic local state update
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

    // Persist to local database
    if (event.userRole === 'driver') {
      await removeSignup(event.scheduleId, event.timestamp, event.driverMemberId);
    } else {
      // Remove ride if any, then register drive
      await removeSignup(event.scheduleId, event.timestamp, event.riderMemberId);
      await registerSignup({
        scheduleId: event.scheduleId,
        eventTimestamp: event.timestamp,
        memberId: event.driverMemberId,
        role: 'driver',
        status: 'scheduled',
      });
    }
    // Reload full database data
    await loadData();
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      <View style={styles.offlineBanner}>
        <Text style={styles.offlineText}>✓ Local Database Synced Off-line</Text>
      </View>

      <Text style={styles.sectionHeader}>Upcoming Commutes</Text>

      {events.map((event) => (
        <View key={event.id} style={styles.card}>
          <Text style={styles.eventTitle}>{event.title}</Text>
          <Text style={styles.eventTime}>{event.timeText}</Text>

          <View style={styles.participantSection}>
            <Text style={styles.subLabel}>
              Driver: <Text style={styles.val}>{event.driverName || 'No driver assigned yet'}</Text>
            </Text>
            <Text style={styles.subLabel}>
              Riders:{' '}
              <Text style={styles.val}>
                {event.ridersNames.length > 0 ? event.ridersNames.join(', ') : 'No riders registered'}
              </Text>
            </Text>
          </View>

          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={[
                styles.actionBtn,
                event.userRole === 'rider' ? styles.btnActive : styles.btnInactive,
              ]}
              onPress={() => toggleRide(event)}
            >
              <Text
                style={[
                  styles.btnText,
                  event.userRole === 'rider' ? styles.textActive : styles.textInactive,
                ]}
              >
                {event.userRole === 'rider' ? '✓ Registered' : 'Ride'}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.actionBtn,
                event.userRole === 'driver' ? styles.btnActive : styles.btnInactive,
              ]}
              onPress={() => toggleDrive(event)}
            >
              <Text
                style={[
                  styles.btnText,
                  event.userRole === 'driver' ? styles.textActive : styles.textInactive,
                ]}
              >
                {event.userRole === 'driver' ? '✓ Driving' : 'Drive'}
              </Text>
            </TouchableOpacity>
          </View>

          {event.userRole === 'driver' && (
            <TouchableOpacity
              style={styles.startDriveBtn}
              onPress={() => router.push({
                pathname: '/route-active',
                params: { scheduleId: event.scheduleId, eventTimestamp: event.timestamp.toString() }
              })}
            >
              <Text style={styles.startDriveBtnText}>Start Driving Route</Text>
            </TouchableOpacity>
          )}
        </View>
      ))}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc',
    padding: 16,
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  offlineBanner: {
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
    borderRadius: 8,
    padding: 12,
    marginBottom: 20,
    alignItems: 'center',
  },
  offlineText: {
    color: '#065f46',
    fontWeight: '600',
    fontSize: 14,
  },
  sectionHeader: {
    fontSize: 20,
    fontWeight: 'bold',
    color: '#0f172a',
    marginBottom: 16,
  },
  card: {
    backgroundColor: '#fff',
    borderRadius: 12,
    padding: 16,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 1 },
    shadowOpacity: 0.05,
    shadowRadius: 2,
    elevation: 2,
  },
  eventTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  eventTime: {
    fontSize: 14,
    color: '#64748b',
    marginTop: 4,
    marginBottom: 12,
  },
  participantSection: {
    backgroundColor: '#f1f5f9',
    borderRadius: 8,
    padding: 12,
    gap: 6,
    marginBottom: 16,
  },
  subLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#475569',
  },
  val: {
    fontWeight: 'normal',
    color: '#1e293b',
  },
  buttonRow: {
    flexDirection: 'row',
    gap: 12,
  },
  actionBtn: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 8,
    alignItems: 'center',
    borderWidth: 1,
  },
  btnActive: {
    backgroundColor: '#dbeafe',
    borderColor: '#93c5fd',
  },
  btnInactive: {
    backgroundColor: '#fff',
    borderColor: '#cbd5e1',
  },
  btnText: {
    fontWeight: 'bold',
    fontSize: 14,
  },
  textActive: {
    color: '#1d4ed8',
  },
  textInactive: {
    color: '#475569',
  },
  startDriveBtn: {
    backgroundColor: '#10b981',
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  startDriveBtnText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 15,
  },
});
