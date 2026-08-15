import React, { useState, useEffect } from 'react';
import { StyleSheet, View, ScrollView } from 'react-native';
import {
  Text,
  Card,
  TextInput,
  Button,
  ActivityIndicator,
  useTheme,
  Icon,
} from 'react-native-paper';
import { db } from '../../db/client';
import { cachedSchedules, cachedFamilyMembers } from '../../db/schema';
import { createCircle, inviteMember } from '../../utils/matrixClient';

interface Circle {
  id: string;
  name: string;
  membersCount: number;
}

export default function CirclesScreen() {
  const theme = useTheme();

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
        <ActivityIndicator size="large" animating={true} color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      <Text variant="titleLarge" style={styles.sectionTitle}>
        Your Coordination Circles
      </Text>

      {circles.map((item) => {
        const isSelected = selectedCircleId === item.id;
        return (
          <Card
            key={item.id}
            style={[styles.circleCard, isSelected && styles.circleCardSelected]}
            mode="elevated"
            onPress={() => setSelectedCircleId(item.id)}
          >
            <Card.Content style={styles.cardContent}>
              <View style={styles.cardInfo}>
                <Text variant="titleMedium" style={styles.circleName}>
                  {item.name}
                </Text>

                <View style={styles.metaRow}>
                  <Icon source="shield-check" size={16} color="#10b981" />
                  <Text variant="bodySmall" style={styles.circleMeta}>
                    {item.membersCount} members • End-to-End Encrypted
                  </Text>
                </View>
              </View>

              {isSelected && (
                <Text variant="labelMedium" style={styles.activeIndicator}>
                  ✓ Selected
                </Text>
              )}
            </Card.Content>
          </Card>
        );
      })}

      <Card style={styles.formCard} mode="elevated">
        <Card.Content style={styles.formContent}>
          <Text variant="titleMedium" style={styles.formTitle}>
            Create New Circle
          </Text>
          <TextInput
            label="Circle Name"
            value={newCircleName}
            onChangeText={setNewCircleName}
            placeholder="e.g. Neighborhood Swim Club"
            mode="outlined"
            left={<TextInput.Icon icon="account-group" />}
          />
          <Button
            mode="contained"
            onPress={handleCreateCircle}
            style={styles.button}
            icon="plus"
          >
            Create Circle
          </Button>
        </Card.Content>
      </Card>

      <Card style={styles.formCard} mode="elevated">
        <Card.Content style={styles.formContent}>
          <Text variant="titleMedium" style={styles.formTitle}>
            Invite Member to Circle
          </Text>
          <TextInput
            label="Matrix ID or Email"
            value={inviteEmail}
            onChangeText={setInviteEmail}
            placeholder="@username:homeserver.org"
            mode="outlined"
            autoCapitalize="none"
            left={<TextInput.Icon icon="email-plus" />}
          />
          <Button
            mode="contained"
            buttonColor="#10b981"
            onPress={handleInviteMember}
            style={styles.button}
            icon="send"
          >
            Send Matrix Invitation
          </Button>
        </Card.Content>
      </Card>
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
  sectionTitle: {
    fontWeight: 'bold',
    color: '#0f172a',
    marginBottom: 12,
  },
  circleCard: {
    marginBottom: 12,
    backgroundColor: '#ffffff',
    borderRadius: 12,
  },
  circleCardSelected: {
    borderColor: '#2563eb',
    borderWidth: 1.5,
    backgroundColor: '#eff6ff',
  },
  cardContent: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  cardInfo: {
    flex: 1,
  },
  circleName: {
    fontWeight: 'bold',
    color: '#1e293b',
  },
  metaRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    marginTop: 4,
  },
  circleMeta: {
    color: '#10b981',
    fontWeight: '600',
  },
  activeIndicator: {
    color: '#2563eb',
    fontWeight: 'bold',
  },
  formCard: {
    marginTop: 16,
    backgroundColor: '#ffffff',
    borderRadius: 12,
  },
  formContent: {
    gap: 12,
  },
  formTitle: {
    fontWeight: 'bold',
    color: '#1e293b',
  },
  button: {
    borderRadius: 8,
    marginTop: 4,
  },
});
