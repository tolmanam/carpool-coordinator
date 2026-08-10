import React, { useState } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';

interface EventInstance {
  id: string;
  title: string;
  time: string;
  riders: string[];
  driver: string | null;
  userSignedUp: 'rider' | 'driver' | null;
}

const mockEvents: EventInstance[] = [
  {
    id: '1',
    title: 'U10 Soccer Practice',
    time: 'Today, 4:00 PM - 5:30 PM',
    riders: ['John Connor', 'Sarah Smith'],
    driver: 'Alice Johnson',
    userSignedUp: null,
  },
  {
    id: '2',
    title: 'Westside Math Tutoring',
    time: 'Tomorrow, 3:30 PM - 4:30 PM',
    riders: [],
    driver: null,
    userSignedUp: null,
  },
];

export default function ScheduleScreen() {
  const router = useRouter();
  const [events, setEvents] = useState<EventInstance[]>(mockEvents);

  const toggleRide = (id: string) => {
    // Optimistic UI state update
    setEvents((prev) =>
      prev.map((ev) => {
        if (ev.id !== id) return ev;
        if (ev.userSignedUp === 'rider') {
          return {
            ...ev,
            userSignedUp: null,
            riders: ev.riders.filter((r) => r !== 'You'),
          };
        } else {
          return {
            ...ev,
            userSignedUp: 'rider',
            riders: [...ev.riders.filter((r) => r !== 'You'), 'You'],
            driver: ev.driver === 'You' ? null : ev.driver,
          };
        }
      })
    );
  };

  const toggleDrive = (id: string) => {
    // Optimistic UI state update
    setEvents((prev) =>
      prev.map((ev) => {
        if (ev.id !== id) return ev;
        if (ev.userSignedUp === 'driver') {
          return {
            ...ev,
            userSignedUp: null,
            driver: null,
          };
        } else {
          return {
            ...ev,
            userSignedUp: 'driver',
            driver: 'You',
            riders: ev.riders.filter((r) => r !== 'You'),
          };
        }
      })
    );
  };

  return (
    <ScrollView style={styles.container}>
      <View style={styles.offlineBanner}>
        <Text style={styles.offlineText}>✓ Local Database Synced Off-line</Text>
      </View>

      <Text style={styles.sectionHeader}>Upcoming Commutes</Text>

      {events.map((event) => (
        <View key={event.id} style={styles.card}>
          <Text style={styles.eventTitle}>{event.title}</Text>
          <Text style={styles.eventTime}>{event.time}</Text>

          <View style={styles.participantSection}>
            <Text style={styles.subLabel}>
              Driver: <Text style={styles.val}>{event.driver || 'No driver assigned yet'}</Text>
            </Text>
            <Text style={styles.subLabel}>
              Riders:{' '}
              <Text style={styles.val}>
                {event.riders.length > 0 ? event.riders.join(', ') : 'No riders registered'}
              </Text>
            </Text>
          </View>

          <View style={styles.buttonRow}>
            <TouchableOpacity
              style={[
                styles.actionBtn,
                event.userSignedUp === 'rider' ? styles.btnActive : styles.btnInactive,
              ]}
              onPress={() => toggleRide(event.id)}
            >
              <Text
                style={[
                  styles.btnText,
                  event.userSignedUp === 'rider' ? styles.textActive : styles.textInactive,
                ]}
              >
                {event.userSignedUp === 'rider' ? '✓ Registered' : 'Ride'}
              </Text>
            </TouchableOpacity>

            <TouchableOpacity
              style={[
                styles.actionBtn,
                event.userSignedUp === 'driver' ? styles.btnActive : styles.btnInactive,
              ]}
              onPress={() => toggleDrive(event.id)}
            >
              <Text
                style={[
                  styles.btnText,
                  event.userSignedUp === 'driver' ? styles.textActive : styles.textInactive,
                ]}
              >
                {event.userSignedUp === 'driver' ? '✓ Driving' : 'Drive'}
              </Text>
            </TouchableOpacity>
          </View>

          {event.userSignedUp === 'driver' && (
            <TouchableOpacity
              style={styles.startDriveBtn}
              onPress={() => router.push('/route-active')}
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
