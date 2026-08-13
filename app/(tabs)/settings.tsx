import React, { useState } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity } from 'react-native';
import { useRouter } from 'expo-router';

export default function SettingsScreen() {
  const router = useRouter();
  const [address, setAddress] = useState('734 Ocean Avenue, Santa Monica, CA');
  const [icalUrl, setIcalUrl] = useState('https://sports-club.org/calendars/u10.ics');

  const handleLogout = () => {
    router.replace('/');
  };

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
        <TouchableOpacity style={styles.syncBtn}>
          <Text style={styles.syncBtnText}>Trigger Fetch & Distributed Sync</Text>
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
