import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TouchableOpacity, Switch } from 'react-native';
import { useRouter } from 'expo-router';

interface Stop {
  name: string;
  type: string;
  scheduledTime: string;
  actualTime: string;
}

export default function RouteActiveScreen() {
  const router = useRouter();
  const [activeDrive, setActiveDrive] = useState(false);
  const [delayReported, setDelayReported] = useState(false);

  // Simple countdown to destination
  const [etaMinutes, setEtaMinutes] = useState(25);

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (activeDrive) {
      interval = setInterval(() => {
        setEtaMinutes((prev) => (prev > 1 ? prev - 1 : 25));
      }, 5000);
    }
    return () => clearInterval(interval);
  }, [activeDrive]);

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
          <Text style={styles.cardSub}>Destination: Clover Park Field 2</Text>

          <View style={styles.stopsTimeline}>
            <View style={styles.stopItem}>
              <Text style={styles.stopName}>1. Start: Alice (You)</Text>
              <Text style={styles.stopTime}>Scheduled: 3:45 PM • Actual: 3:45 PM</Text>
            </View>
            <View style={styles.stopItem}>
              <Text style={styles.stopName}>2. Pickup: John Connor</Text>
              <Text style={styles.stopTime}>Scheduled: 3:52 PM • ETA: 3:55 PM</Text>
            </View>
            <View style={styles.stopItem}>
              <Text style={styles.stopName}>3. Pickup: Sarah Smith</Text>
              <Text style={styles.stopTime}>Scheduled: 3:56 PM • ETA: 3:59 PM</Text>
            </View>
            <View style={styles.stopItem}>
              <Text style={[styles.stopName, { fontWeight: 'bold' }]}>4. Destination: Clover Park</Text>
              <Text style={styles.stopTime}>Scheduled: 4:10 PM • ETA: 4:12 PM</Text>
            </View>
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
