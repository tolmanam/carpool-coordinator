import React, { useState, useEffect } from 'react';
import { StyleSheet, View, ScrollView } from 'react-native';
import {
  Text,
  TextInput,
  Button,
  Card,
  Switch,
  ActivityIndicator,
  Surface,
  useTheme,
  Icon,
} from 'react-native-paper';
import { useRouter } from 'expo-router';
import { authenticateMatrix, getSessionInfo, authenticateMatrixSSO } from '../utils/matrixClient';

export default function LoginScreen() {
  const router = useRouter();
  const theme = useTheme();

  const [homeserver, setHomeserver] = useState('https://matrix.org');
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [isOffline, setIsOffline] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
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

  const handleSSOLogin = async () => {
    setLoading(true);
    try {
      await authenticateMatrixSSO(homeserver);
      router.replace('/(tabs)/schedule');
    } catch (e) {
      console.error(e);
      setLoading(false);
    }
  };

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" animating={true} color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView contentContainerStyle={styles.scrollContainer}>
      <Card style={[styles.card, isOffline && styles.cardOffline]} mode="elevated">
        <Card.Content>
          <Surface style={styles.headerBadge} elevation={1}>
            <View style={styles.badgeLeft}>
              <Icon source={isOffline ? 'wifi-off' : 'wifi'} size={20} color={isOffline ? '#f43f5e' : '#10b981'} />
              <Text variant="labelLarge" style={styles.badgeText}>
                {isOffline ? 'OFFLINE MODE' : 'ONLINE'}
              </Text>
            </View>
            <Switch
              value={isOffline}
              onValueChange={setIsOffline}
              color={theme.colors.primary}
            />
          </Surface>

          <Text variant="headlineMedium" style={styles.title}>
            Carpool Coordinator
          </Text>
          <Text variant="bodyMedium" style={styles.subtitle}>
            Decentralized & Encrypted Group Commutes
          </Text>

          <View style={styles.form}>
            <TextInput
              label="Homeserver URL"
              value={homeserver}
              onChangeText={setHomeserver}
              placeholder="https://matrix.org"
              mode="outlined"
              autoCapitalize="none"
              left={<TextInput.Icon icon="server" />}
            />

            <TextInput
              label="Username"
              value={username}
              onChangeText={setUsername}
              placeholder="@username:matrix.org"
              mode="outlined"
              autoCapitalize="none"
              left={<TextInput.Icon icon="account" />}
            />

            <TextInput
              label="Password"
              value={password}
              onChangeText={setPassword}
              placeholder="••••••••"
              secureTextEntry
              mode="outlined"
              autoCapitalize="none"
              left={<TextInput.Icon icon="lock" />}
            />

            <Button
              mode="contained"
              onPress={handleLogin}
              style={styles.button}
              contentStyle={styles.buttonContent}
              icon="login"
            >
              Sign In with Matrix
            </Button>

            <Button
              mode="outlined"
              onPress={handleSSOLogin}
              style={styles.ssoButton}
              contentStyle={styles.buttonContent}
              icon="shield-account"
            >
              Sign In with SSO / OIDC
            </Button>
          </View>
        </Card.Content>
      </Card>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  scrollContainer: {
    flexGrow: 1,
    padding: 20,
    justifyContent: 'center',
    backgroundColor: '#f8fafc',
  },
  loadingContainer: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
  },
  card: {
    paddingVertical: 12,
    borderRadius: 16,
    backgroundColor: '#ffffff',
  },
  cardOffline: {
    backgroundColor: '#fff1f2',
  },
  headerBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 8,
    borderRadius: 12,
    backgroundColor: '#f1f5f9',
    marginBottom: 24,
  },
  badgeLeft: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
  },
  badgeText: {
    fontWeight: '700',
    color: '#334155',
  },
  title: {
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#0f172a',
    marginBottom: 4,
  },
  subtitle: {
    color: '#64748b',
    textAlign: 'center',
    marginBottom: 24,
  },
  form: {
    gap: 14,
  },
  button: {
    marginTop: 12,
    borderRadius: 8,
  },
  ssoButton: {
    marginTop: 4,
    borderRadius: 8,
  },
  buttonContent: {
    paddingVertical: 6,
  },
});
