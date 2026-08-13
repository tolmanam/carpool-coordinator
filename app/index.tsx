import React, { useState, useEffect } from 'react';
import { StyleSheet, Text, View, TextInput, TouchableOpacity, Switch, ActivityIndicator } from 'react-native';
import { useRouter } from 'expo-router';
import { authenticateMatrix, getSessionInfo } from '../utils/matrixClient';

export default function LoginScreen() {
  const router = useRouter();
  const [homeserver, setHomeserver] = useState('https://matrix.org');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isOffline, setIsOffline] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Check if user is already logged in
    getSessionInfo().then((session) => {
      if (session.isLoggedIn) {
        router.replace('/(tabs)/schedule');
      } else {
        setLoading(false);
      }
    });
  }, []);

  const handleLogin = async () => {
    if (!username) return;
    setLoading(true);
    try {
      await authenticateMatrix(username, homeserver);
      router.replace('/(tabs)/schedule');
    } catch (e) {
      console.error(e);
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.container}>
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <View style={[styles.container, isOffline && styles.containerOffline]}>
      <View style={styles.headerBadge}>
        <Text style={styles.badgeText}>{isOffline ? 'OFFLINE MODE' : 'ONLINE'}</Text>
        <Switch
          value={isOffline}
          onValueChange={setIsOffline}
          trackColor={{ false: '#767577', true: '#f43f5e' }}
          thumbColor={isOffline ? '#fff' : '#f4f3f4'}
        />
      </View>

      <Text style={styles.title}>Carpool Coordinator</Text>
      <Text style={styles.subtitle}>Decentralized & Encrypted Group Commutes</Text>

      <View style={styles.form}>
        <Text style={styles.label}>Homeserver URL</Text>
        <TextInput
          style={styles.input}
          value={homeserver}
          onChangeText={setHomeserver}
          placeholder="https://matrix.org"
          autoCapitalize="none"
        />

        <Text style={styles.label}>Username</Text>
        <TextInput
          style={styles.input}
          value={username}
          onChangeText={setUsername}
          placeholder="@username:matrix.org"
          autoCapitalize="none"
        />

        <Text style={styles.label}>Password</Text>
        <TextInput
          style={styles.input}
          value={password}
          onChangeText={setPassword}
          placeholder="••••••••"
          secureTextEntry
          autoCapitalize="none"
        />

        <TouchableOpacity style={styles.button} onPress={handleLogin}>
          <Text style={styles.buttonText}>Sign In with Matrix</Text>
        </TouchableOpacity>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    padding: 24,
    justifyContent: 'center',
  },
  containerOffline: {
    backgroundColor: '#fef2f2',
  },
  headerBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: 8,
    borderRadius: 8,
    backgroundColor: '#f1f5f9',
    marginBottom: 32,
  },
  badgeText: {
    fontWeight: 'bold',
    color: '#334155',
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#0f172a',
    marginBottom: 8,
  },
  subtitle: {
    fontSize: 16,
    color: '#64748b',
    textAlign: 'center',
    marginBottom: 32,
  },
  form: {
    gap: 16,
  },
  label: {
    fontSize: 14,
    fontWeight: '600',
    color: '#334155',
  },
  input: {
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    padding: 12,
    fontSize: 16,
    backgroundColor: '#f8fafc',
  },
  button: {
    backgroundColor: '#2563eb',
    padding: 16,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 16,
  },
  buttonText: {
    color: '#fff',
    fontSize: 16,
    fontWeight: 'bold',
  },
});
