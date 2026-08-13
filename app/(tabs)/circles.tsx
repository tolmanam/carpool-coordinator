import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity, ActivityIndicator } from 'react-native';
import { db } from '../../db/client';
import { cachedSchedules, cachedFamilyMembers } from '../../db/schema';
import { createCircle, inviteMember } from '../../utils/matrixClient';

interface Circle {
  id: string;
  name: string;
  membersCount: number;
}

export default function CirclesScreen() {
  const [loading, setLoading] = useState(true);
  const [circles, setCircles] = useState<Circle[]>([]);
  const [newCircleName, setNewCircleName] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');
  const [selectedCircleId, setSelectedCircleId] = useState<string | null>(null);

  const loadData = async () => {
    try {
      const schedules = await db.select().from(cachedSchedules).all();
      const members = await db.select().from(cachedFamilyMembers).all();

      const mappedCircles: Circle[] = schedules.map((sch) => {
        // Find how many cached family members exist
        const count = members.length || 1;
        return {
          id: sch.scheduleId,
          name: sch.title,
          membersCount: count,
        };
      });

      setCircles(mappedCircles);
      if (mappedCircles.length > 0 && !selectedCircleId) {
        setSelectedCircleId(mappedCircles[0].id);
      }
    } catch (e) {
      console.error(e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const handleCreateCircle = async () => {
    if (!newCircleName.trim()) return;
    setLoading(true);
    try {
      const newSchedId = await createCircle(newCircleName);
      setSelectedCircleId(newSchedId);
      setNewCircleName('');
      await loadData();
    } catch (e) {
      console.error(e);
      setLoading(false);
    }
  };

  const handleInviteMember = async () => {
    if (!inviteEmail.trim() || !selectedCircleId) return;
    setLoading(true);
    try {
      await inviteMember(selectedCircleId, inviteEmail);
      setInviteEmail('');
      await loadData();
    } catch (e) {
      console.error(e);
      setLoading(false);
    }
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
      <Text style={styles.sectionTitle}>Your Coordination Circles</Text>

      {circles.map((item) => (
        <TouchableOpacity
          key={item.id}
          style={[
            styles.circleCard,
            selectedCircleId === item.id && styles.circleCardSelected,
          ]}
          onPress={() => setSelectedCircleId(item.id)}
        >
          <View>
            <Text style={styles.circleName}>{item.name}</Text>
            <Text style={styles.circleMeta}>{item.membersCount} members • End-to-End Encrypted</Text>
          </View>
          {selectedCircleId === item.id && (
            <Text style={styles.activeIndicator}>✓ Selected</Text>
          )}
        </TouchableOpacity>
      ))}

      <View style={styles.formContainer}>
        <Text style={styles.formTitle}>Create New Circle</Text>
        <TextInput
          style={styles.input}
          value={newCircleName}
          onChangeText={setNewCircleName}
          placeholder="e.g. Neighborhood Swim Club"
        />
        <TouchableOpacity style={styles.button} onPress={handleCreateCircle}>
          <Text style={styles.buttonText}>Create Circle</Text>
        </TouchableOpacity>
      </View>

      <View style={styles.formContainer}>
        <Text style={styles.formTitle}>Invite Member to Circle</Text>
        <TextInput
          style={styles.input}
          value={inviteEmail}
          onChangeText={setInviteEmail}
          placeholder="@username:homeserver.org"
        />
        <TouchableOpacity style={[styles.button, { backgroundColor: '#10b981' }]} onPress={handleInviteMember}>
          <Text style={styles.buttonText}>Send Matrix Invitation</Text>
        </TouchableOpacity>
      </View>
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
    fontSize: 20,
    fontWeight: 'bold',
    color: '#0f172a',
    marginBottom: 16,
  },
  circleCard: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 16,
    marginBottom: 12,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  circleCardSelected: {
    borderColor: '#2563eb',
    backgroundColor: '#eff6ff',
  },
  circleName: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  circleMeta: {
    fontSize: 12,
    color: '#10b981',
    fontWeight: '600',
    marginTop: 4,
  },
  activeIndicator: {
    color: '#2563eb',
    fontWeight: 'bold',
    fontSize: 12,
  },
  formContainer: {
    backgroundColor: '#fff',
    borderRadius: 8,
    padding: 16,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    marginTop: 24,
  },
  formTitle: {
    fontSize: 16,
    fontWeight: 'bold',
    color: '#1e293b',
    marginBottom: 12,
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
  button: {
    backgroundColor: '#2563eb',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
  },
  buttonText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 14,
  },
});
