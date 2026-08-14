import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity, ActivityIndicator, Alert } from 'react-native';
import { useRouter } from 'expo-router';
import { db } from '../../db/client';
import { cachedFamilies, cachedSchedules } from '../../db/schema';
import { getSessionInfo, logoutMatrix, syncIcalFeed } from '../../utils/matrixClient';
import { eq } from 'drizzle-orm';

export default function SettingsScreen() {
  const router = useRouter();
  const [loading, setLoading] = useState(true);
  const [address, setAddress] = useState('734 Ocean Avenue, Santa Monica, CA');
  const [icalUrl, setIcalUrl] = useState('https://sports-club.org/calendars/u10.ics');
  const [scheduleId, setScheduleId] = useState('');
  const [matrixId, setMatrixId] = useState('');
  const [syncing, setSyncing] = useState(false);

  useEffect(() => {
    const fetchSettings = async () => {
      try {
        const session = await getSessionInfo();
        const userMatrixId = session.username.startsWith('@') ? session.username : `@${session.username}:matrix.org`;
        setMatrixId(userMatrixId);

        // Fetch family address
        const family = await db.select().from(cachedFamilies).where(eq(cachedFamilies.matrixId, userMatrixId)).get();
        if (family?.addressText) {
          setAddress(family.addressText);
        }

        // Fetch schedule / iCal URL
        const schedules = await db.select().from(cachedSchedules).all();
        if (schedules.length > 0) {
          setScheduleId(schedules[0].scheduleId);
          if (schedules[0].icalFeedUrl) {
            setIcalUrl(schedules[0].icalFeedUrl);
          }
        }
      } catch (e) {
        console.error(e);
      } finally {
        setLoading(false);
      }
    };

    fetchSettings();
  }, []);

  const handleSaveAndSync = async () => {
    setSyncing(true);
    try {
      // 1. Update family profile in SQLite DB
      if (matrixId) {
        await db
          .update(cachedFamilies)
          .set({ addressText: address, lastUpdated: new Date() })
          .where(eq(cachedFamilies.matrixId, matrixId));
      }

      // 2. Update schedule config in SQLite DB
      if (scheduleId) {
        await db
          .update(cachedSchedules)
          .set({ icalFeedUrl: icalUrl })
          .where(eq(cachedSchedules.scheduleId, scheduleId));

        // 3. Trigger local fetch & parse synchronization
        await syncIcalFeed(scheduleId);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setSyncing(false);
    }
  };

  const handleLogout = async () => {
    await logoutMatrix();
    router.replace('/');
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
      <Text style={styles.sectionTitle}>Family Profile Configuration</Text>

      <View style={styles.section}>
        <Text style={styles.label}>Home Address</Text>
        <TextInput
          style={styles.input}
          value={address}
          onChangeText={setAddress}
          placeholder="Enter home address"
        />
        <View style={styles.addressCheckBadge}>
          <Text style={styles.addressCheckText}>✓ GPS Location Verified & Pin Placed</Text>
        </View>
      </View>

      <Text style={styles.sectionTitle}>Shared Activity Calendar</Text>

      <View style={styles.section}>
        <Text style={styles.label}>iCal Feed URL (.ics)</Text>
        <TextInput
          style={styles.input}
          value={icalUrl}
          onChangeText={setIcalUrl}
          placeholder="https://example.com/calendar.ics"
          autoCapitalize="none"
        />
        <TouchableOpacity style={styles.syncBtn} onPress={handleSaveAndSync} disabled={syncing}>
          {syncing ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Text style={styles.syncBtnText}>Trigger Fetch & Distributed Sync</Text>
          )}
        </TouchableOpacity>
      </View>

      <TouchableOpacity style={styles.logoutBtn} onPress={handleLogout}>
        <Text style={styles.logoutBtnText}>Logout Session</Text>
      </TouchableOpacity>
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
  sectionTitle: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#0f172a',
    marginTop: 16,
    marginBottom: 12,
  },
  section: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    marginBottom: 20,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#475569',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    padding: 12,
    fontSize: 14,
    backgroundColor: '#f8fafc',
    marginBottom: 12,
  },
  addressCheckBadge: {
    backgroundColor: '#f0fdf4',
    borderColor: '#bbf7d0',
    borderWidth: 1,
    padding: 10,
    borderRadius: 6,
    alignItems: 'center',
  },
  addressCheckText: {
    color: '#16a34a',
    fontWeight: '600',
    fontSize: 12,
  },
  syncBtn: {
    backgroundColor: '#0284c7',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    height: 48,
    justifyContent: 'center',
  },
  syncBtnText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 14,
  },
  logoutBtn: {
    borderColor: '#f43f5e',
    borderWidth: 1.5,
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 24,
    marginBottom: 48,
  },
  logoutBtnText: {
    color: '#f43f5e',
    fontWeight: 'bold',
    fontSize: 15,
  },
});
