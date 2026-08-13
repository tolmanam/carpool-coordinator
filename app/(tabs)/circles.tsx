import React, { useState } from 'react';
import { StyleSheet, Text, View, ScrollView, TextInput, TouchableOpacity, FlatList } from 'react-native';

interface Circle {
  id: string;
  name: string;
  membersCount: number;
}

export default function CirclesScreen() {
  const [circles, setCircles] = useState<Circle[]>([
    { id: '1', name: 'Westside Soccer Family Club', membersCount: 4 },
    { id: '2', name: 'High School Commute Group', membersCount: 3 },
  ]);
  const [newCircleName, setNewCircleName] = useState('');
  const [inviteEmail, setInviteEmail] = useState('');

  const handleCreateCircle = () => {
    if (!newCircleName.trim()) return;
    const newCircle: Circle = {
      id: Date.now().toString(),
      name: newCircleName,
      membersCount: 1,
    };
    setCircles([...circles, newCircle]);
    setNewCircleName('');
  };

  return (
    <ScrollView style={styles.container}>
      <Text style={styles.sectionTitle}>Your Coordination Circles</Text>

      {circles.map((item) => (
        <View key={item.id} style={styles.circleCard}>
          <View>
            <Text style={styles.circleName}>{item.name}</Text>
            <Text style={styles.circleMeta}>{item.membersCount} members • End-to-End Encrypted</Text>
          </View>
        </View>
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
        <TouchableOpacity style={[styles.button, { backgroundColor: '#10b981' }]} onPress={() => setInviteEmail('')}>
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
