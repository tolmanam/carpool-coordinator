import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  ScrollView,
  Alert,
} from 'react-native';
import {
  Text,
  Card,
  TextInput,
  Button,
  Chip,
  ActivityIndicator,
  SegmentedButtons,
  IconButton,
  useTheme,
  Divider,
  Icon,
} from 'react-native-paper';
import { useRouter } from 'expo-router';
import { db } from '../../db/client';
import { cachedFamilies, cachedFamilyMembers, cachedSchedules } from '../../db/schema';
import {
  getSessionInfo,
  logoutMatrix,
  reauthenticateAndClearCache,
  getNotificationSound,
  setNotificationSound,
  getThemeMode,
  setThemeMode,
  getUserProfileRoles,
  updateUserProfileRoles,
  updateFamilyName,
  addFamilyMember,
  removeFamilyMember,
  createCarpoolGroup,
  updateGroupEventSources,
  addParticipantFamily,
  removeParticipantFamily,
} from '../../utils/matrixClient';
import { eq } from 'drizzle-orm';

export default function SettingsScreen() {
  const router = useRouter();
  const theme = useTheme();

  const [loading, setLoading] = useState(true);
  const [processing, setProcessing] = useState(false);

  // 1. System Configuration
  const [username, setUsername] = useState('');
  const [homeserver, setHomeserver] = useState('https://matrix.org');
  const [notificationSound, setNotificationSoundState] = useState('default');
  const [themeMode, setThemeModeState] = useState<'light' | 'dark' | 'system'>('system');

  // 2. Profile Configuration
  const [userRoles, setUserRoles] = useState<string[]>(['Parent', 'Driver']);

  // 3. Family Group Configuration
  const [matrixId, setMatrixId] = useState('');
  const [familyName, setFamilyName] = useState('');
  const [address, setAddress] = useState('734 Ocean Avenue, Santa Monica, CA');
  const [members, setMembers] = useState<Array<{ memberId: string; name: string; role: string }>>([]);
  const [newMemberName, setNewMemberName] = useState('');
  const [newMemberRoles, setNewMemberRoles] = useState<string[]>(['Participant']);

  // 4. Carpool Group Configuration
  const [schedules, setSchedules] = useState<Array<any>>([]);
  const [selectedScheduleId, setSelectedScheduleId] = useState<string | null>(null);
  const [newGroupName, setNewGroupName] = useState('');
  const [newEventSource, setNewEventSource] = useState('');
  const [additionalFeedUrl, setAdditionalFeedUrl] = useState('');
  const [inviteFamilyId, setInviteFamilyId] = useState('');

  const loadAllData = async () => {
    try {
      const session = await getSessionInfo();
      setUsername(session.username);
      setHomeserver(session.homeserver);

      const userMatrixId = session.username.startsWith('@')
        ? session.username
        : `@${session.username}:matrix.org`;
      setMatrixId(userMatrixId);

      // System Settings
      const sound = await getNotificationSound();
      setNotificationSoundState(sound);
      const thm = await getThemeMode();
      setThemeModeState(thm);

      // Profile Roles
      const roles = await getUserProfileRoles();
      setUserRoles(roles);

      // Family Data
      const family = await db
        .select()
        .from(cachedFamilies)
        .where(eq(cachedFamilies.matrixId, userMatrixId))
        .get();
      if (family) {
        if (family.familyName) setFamilyName(family.familyName);
        if (family.addressText) setAddress(family.addressText);
      }

      const famMembers = await db
        .select()
        .from(cachedFamilyMembers)
        .where(eq(cachedFamilyMembers.matrixId, userMatrixId))
        .all();
      setMembers(famMembers);

      // Carpool Groups
      const groupList = await db.select().from(cachedSchedules).all();
      setSchedules(groupList);
      if (groupList.length > 0 && !selectedScheduleId) {
        setSelectedScheduleId(groupList[0].scheduleId);
      }
    } catch (e) {
      console.error('Error loading settings data:', e);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadAllData();
  }, []);

  // System Config Handlers
  const handleReauthenticate = async () => {
    if (!username.trim() || !homeserver.trim()) return;
    setProcessing(true);
    try {
      await reauthenticateAndClearCache(username, homeserver);
      await loadAllData();
      Alert.alert('System Configuration', 'Matrix re-authentication complete and cache synchronized.');
    } catch (e: any) {
      Alert.alert('Error', e.message || 'Failed to re-authenticate.');
    } finally {
      setProcessing(false);
    }
  };

  const handleSaveSound = async (sound: string) => {
    setNotificationSoundState(sound);
    await setNotificationSound(sound);
  };

  const handleSaveTheme = async (thm: 'light' | 'dark' | 'system') => {
    setThemeModeState(thm);
    await setThemeMode(thm);
  };

  // Profile Config Handlers
  const toggleUserRole = async (role: string) => {
    let updated: string[];
    if (userRoles.includes(role)) {
      if (userRoles.length === 1) {
        Alert.alert('Profile', 'You must have at least one role assigned.');
        return;
      }
      updated = userRoles.filter((r) => r !== role);
    } else {
      updated = [...userRoles, role];
    }
    setUserRoles(updated);
    await updateUserProfileRoles(updated);
  };

  // Family Group Handlers
  const handleSaveFamilyName = async () => {
    if (!familyName.trim()) return;
    setProcessing(true);
    try {
      await updateFamilyName(familyName);
      Alert.alert('Family Group', 'Family name updated successfully.');
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  const toggleNewMemberRole = (role: string) => {
    if (newMemberRoles.includes(role)) {
      if (newMemberRoles.length === 1) return;
      setNewMemberRoles(newMemberRoles.filter((r) => r !== role));
    } else {
      setNewMemberRoles([...newMemberRoles, role]);
    }
  };

  const handleAddMember = async () => {
    if (!newMemberName.trim()) return;
    setProcessing(true);
    try {
      await addFamilyMember(newMemberName, newMemberRoles);
      setNewMemberName('');
      await loadAllData();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleRemoveMember = async (memberId: string) => {
    setProcessing(true);
    try {
      await removeFamilyMember(memberId);
      await loadAllData();
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  // Carpool Group Handlers
  const handleCreateGroup = async () => {
    if (!newGroupName.trim()) return;
    setProcessing(true);
    try {
      const sources = newEventSource.trim() ? [newEventSource.trim()] : [];
      const newId = await createCarpoolGroup(newGroupName, sources);
      setNewGroupName('');
      setNewEventSource('');
      setSelectedScheduleId(newId);
      await loadAllData();
      Alert.alert('Carpool Group', 'New carpool group created successfully.');
    } catch (e: any) {
      Alert.alert('Permission Error', e.message || 'Only Parents can create Carpool Groups.');
    } finally {
      setProcessing(false);
    }
  };

  const handleAddEventSource = async () => {
    if (!selectedScheduleId || !additionalFeedUrl.trim()) return;
    setProcessing(true);
    try {
      const group = schedules.find((s) => s.scheduleId === selectedScheduleId);
      let existingSources: string[] = [];
      if (group?.eventSourcesJson) {
        try {
          existingSources = JSON.parse(group.eventSourcesJson);
        } catch {}
      } else if (group?.icalFeedUrl) {
        existingSources = [group.icalFeedUrl];
      }

      const updatedSources = [...new Set([...existingSources, additionalFeedUrl.trim()])];
      await updateGroupEventSources(selectedScheduleId, updatedSources);
      setAdditionalFeedUrl('');
      await loadAllData();
      Alert.alert('Carpool Group', 'Event source added and calendar synchronized.');
    } catch (e: any) {
      Alert.alert('Permission Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleInviteFamily = async () => {
    if (!selectedScheduleId || !inviteFamilyId.trim()) return;
    setProcessing(true);
    try {
      await addParticipantFamily(selectedScheduleId, inviteFamilyId.trim());
      setInviteFamilyId('');
      await loadAllData();
      Alert.alert('Carpool Group', 'Family invited to group successfully.');
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleRemoveParticipant = async (familyId: string) => {
    if (!selectedScheduleId) return;
    setProcessing(true);
    try {
      await removeParticipantFamily(selectedScheduleId, familyId);
      await loadAllData();
      Alert.alert('Carpool Group', 'Participant removed from group.');
    } catch (e: any) {
      Alert.alert('Error', e.message);
    } finally {
      setProcessing(false);
    }
  };

  const handleLogout = async () => {
    await logoutMatrix();
    router.replace('/');
  };

  const selectedGroup = schedules.find((s) => s.scheduleId === selectedScheduleId);
  const isParent = userRoles.some((r) => r.toLowerCase() === 'parent');

  if (loading) {
    return (
      <View style={styles.loadingContainer}>
        <ActivityIndicator size="large" animating={true} color={theme.colors.primary} />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container} contentContainerStyle={styles.contentContainer}>
      {/* 1. System Configuration */}
      <Text variant="titleMedium" style={styles.sectionTitle}>
        1. System Configuration
      </Text>
      <Card style={styles.card} mode="elevated">
        <Card.Content style={styles.cardGap}>
          <TextInput
            label="Matrix Username"
            value={username}
            onChangeText={setUsername}
            placeholder="@username:matrix.org"
            mode="outlined"
            autoCapitalize="none"
            left={<TextInput.Icon icon="account" />}
          />

          <TextInput
            label="Matrix Homeserver URL"
            value={homeserver}
            onChangeText={setHomeserver}
            placeholder="https://matrix.org"
            mode="outlined"
            autoCapitalize="none"
            left={<TextInput.Icon icon="server" />}
          />

          <Button
            mode="contained"
            onPress={handleReauthenticate}
            loading={processing}
            disabled={processing}
            icon="sync"
            style={styles.button}
          >
            Re-authenticate Matrix & Clear Cache
          </Button>

          <Divider style={styles.divider} />

          <Text variant="labelLarge" style={styles.subTitle}>
            Notification Sound
          </Text>
          <SegmentedButtons
            value={notificationSound}
            onValueChange={handleSaveSound}
            buttons={[
              { value: 'default', label: 'Default' },
              { value: 'chime', label: 'Chime' },
              { value: 'bell', label: 'Bell' },
              { value: 'mute', label: 'Mute' },
            ]}
          />

          <Text variant="labelLarge" style={[styles.subTitle, { marginTop: 8 }]}>
            Dark Mode / Theme
          </Text>
          <SegmentedButtons
            value={themeMode}
            onValueChange={(val) => handleSaveTheme(val as any)}
            buttons={[
              { value: 'light', label: 'Light' },
              { value: 'dark', label: 'Dark' },
              { value: 'system', label: 'System' },
            ]}
          />
        </Card.Content>
      </Card>

      {/* 2. Profile Configuration */}
      <Text variant="titleMedium" style={styles.sectionTitle}>
        2. Profile Configuration
      </Text>
      <Card style={styles.card} mode="elevated">
        <Card.Content style={styles.cardGap}>
          <Text variant="labelLarge" style={styles.subTitle}>
            My Roles (Multi-Select)
          </Text>
          <Text variant="bodySmall" style={styles.subLabel}>
            Roles are synchronized to Matrix and visible to your family and carpool groups.
          </Text>

          <View style={styles.chipRow}>
            {['Parent', 'Driver', 'Participant'].map((role) => {
              const active = userRoles.includes(role);
              return (
                <Chip
                  key={role}
                  selected={active}
                  onPress={() => toggleUserRole(role)}
                  icon={active ? 'check' : 'account-outline'}
                  mode="outlined"
                  style={styles.chip}
                >
                  {role}
                </Chip>
              );
            })}
          </View>
        </Card.Content>
      </Card>

      {/* 3. Family Group Configuration */}
      <Text variant="titleMedium" style={styles.sectionTitle}>
        3. Family Group Configuration
      </Text>
      <Card style={styles.card} mode="elevated">
        <Card.Content style={styles.cardGap}>
          <TextInput
            label="Family Name"
            value={familyName}
            onChangeText={setFamilyName}
            placeholder="e.g. The Smith Family"
            mode="outlined"
            left={<TextInput.Icon icon="home-heart" />}
          />
          <Button
            mode="outlined"
            onPress={handleSaveFamilyName}
            icon="content-save"
            style={styles.button}
          >
            Save Family Name
          </Button>

          <Divider style={styles.divider} />

          <Text variant="labelLarge" style={styles.subTitle}>
            Family Members
          </Text>
          {members.map((m) => {
            let rolesStr = m.role;
            if (rolesStr.startsWith('[')) {
              try {
                rolesStr = JSON.parse(rolesStr).join(', ');
              } catch {}
            }
            return (
              <View key={m.memberId} style={styles.memberRow}>
                <View style={styles.memberInfo}>
                  <Text variant="titleSmall" style={styles.memberName}>
                    {m.name}
                  </Text>
                  <Text variant="bodySmall" style={styles.memberRole}>
                    Roles: {rolesStr}
                  </Text>
                </View>
                <IconButton
                  icon="delete"
                  iconColor="#f43f5e"
                  size={20}
                  onPress={() => handleRemoveMember(m.memberId)}
                />
              </View>
            );
          })}

          <Text variant="labelLarge" style={[styles.subTitle, { marginTop: 8 }]}>
            Add Family Member
          </Text>
          <TextInput
            label="Member Name"
            value={newMemberName}
            onChangeText={setNewMemberName}
            placeholder="e.g. Sarah"
            mode="outlined"
            left={<TextInput.Icon icon="account-plus" />}
          />
          <Text variant="bodySmall" style={styles.subLabel}>
            Assign Roles:
          </Text>
          <View style={styles.chipRow}>
            {['Parent', 'Driver', 'Participant'].map((role) => {
              const active = newMemberRoles.includes(role);
              return (
                <Chip
                  key={role}
                  selected={active}
                  onPress={() => toggleNewMemberRole(role)}
                  icon={active ? 'check' : 'account-outline'}
                  mode="outlined"
                  style={styles.chip}
                >
                  {role}
                </Chip>
              );
            })}
          </View>

          <Button
            mode="outlined"
            onPress={handleAddMember}
            icon="plus"
            style={styles.button}
          >
            Add Family Member
          </Button>
        </Card.Content>
      </Card>

      {/* 4. Carpool Group Configuration */}
      <Text variant="titleMedium" style={styles.sectionTitle}>
        4. Carpool Group Configuration
      </Text>
      <Card style={styles.card} mode="elevated">
        <Card.Content style={styles.cardGap}>
          <View style={[styles.badge, isParent ? styles.badgeSuccess : styles.badgeWarning]}>
            <Icon
              source={isParent ? 'check-circle' : 'alert-circle'}
              size={18}
              color={isParent ? '#16a34a' : '#b45309'}
            />
            <Text
              variant="labelMedium"
              style={[styles.badgeText, { color: isParent ? '#16a34a' : '#b45309' }]}
            >
              {isParent ? 'Parent Role Active (Can Create Groups)' : 'Parent Role Required to Create Groups'}
            </Text>
          </View>

          <TextInput
            label="Carpool Group Title"
            value={newGroupName}
            onChangeText={setNewGroupName}
            placeholder="e.g. Swim Club Commute"
            mode="outlined"
            left={<TextInput.Icon icon="car-multiple" />}
          />
          <TextInput
            label="Primary iCal Feed URL"
            value={newEventSource}
            onChangeText={setNewEventSource}
            placeholder="https://example.com/feed.ics"
            mode="outlined"
            autoCapitalize="none"
            left={<TextInput.Icon icon="calendar-sync" />}
          />
          <Button
            mode="contained"
            onPress={handleCreateGroup}
            disabled={!isParent || processing}
            icon="plus-circle"
            style={styles.button}
          >
            Create Carpool Group
          </Button>

          {schedules.length > 0 && (
            <>
              <Divider style={styles.divider} />
              <Text variant="labelLarge" style={styles.subTitle}>
                Select Carpool Group to Manage
              </Text>
              <View style={styles.chipRow}>
                {schedules.map((sch) => {
                  const isSelected = selectedScheduleId === sch.scheduleId;
                  return (
                    <Chip
                      key={sch.scheduleId}
                      selected={isSelected}
                      onPress={() => setSelectedScheduleId(sch.scheduleId)}
                      mode="outlined"
                      style={styles.chip}
                    >
                      {sch.title}
                    </Chip>
                  );
                })}
              </View>
            </>
          )}

          {selectedGroup && (
            <Card style={styles.nestedCard} mode="outlined">
              <Card.Content style={styles.cardGap}>
                <Text variant="titleSmall" style={styles.groupTitle}>
                  Manage: {selectedGroup.title}
                </Text>
                <Text variant="bodySmall" style={styles.groupMeta}>
                  Owner: {selectedGroup.ownerId || matrixId}
                </Text>

                <Text variant="labelMedium" style={styles.subTitle}>
                  Event Sources (iCal Feeds)
                </Text>
                {(() => {
                  let sources: string[] = [];
                  if (selectedGroup.eventSourcesJson) {
                    try {
                      sources = JSON.parse(selectedGroup.eventSourcesJson);
                    } catch {}
                  } else if (selectedGroup.icalFeedUrl) {
                    sources = [selectedGroup.icalFeedUrl];
                  }
                  return sources.map((src, idx) => (
                    <Text key={idx} variant="bodySmall" style={styles.sourceText}>
                      • {src}
                    </Text>
                  ));
                })()}

                <TextInput
                  label="Add iCal Feed URL"
                  value={additionalFeedUrl}
                  onChangeText={setAdditionalFeedUrl}
                  placeholder="https://example.com/additional.ics"
                  mode="outlined"
                  autoCapitalize="none"
                  left={<TextInput.Icon icon="link-plus" />}
                />
                <Button
                  mode="outlined"
                  onPress={handleAddEventSource}
                  icon="calendar-plus"
                  style={styles.button}
                >
                  Add iCal Feed
                </Button>

                <Divider style={styles.divider} />

                <Text variant="labelMedium" style={styles.subTitle}>
                  Group Participants
                </Text>
                {(() => {
                  let participants: string[] = [];
                  if (selectedGroup.participantsJson) {
                    try {
                      participants = JSON.parse(selectedGroup.participantsJson);
                    } catch {}
                  }
                  if (participants.length === 0) participants = [matrixId];
                  return participants.map((partId) => (
                    <View key={partId} style={styles.participantRow}>
                      <Text variant="bodySmall" style={styles.participantText}>
                        {partId}
                      </Text>
                      <IconButton
                        icon="account-remove"
                        iconColor="#f43f5e"
                        size={18}
                        onPress={() => handleRemoveParticipant(partId)}
                      />
                    </View>
                  ));
                })()}

                <TextInput
                  label="Invite Family (@username:matrix.org)"
                  value={inviteFamilyId}
                  onChangeText={setInviteFamilyId}
                  placeholder="@username:matrix.org"
                  mode="outlined"
                  autoCapitalize="none"
                  left={<TextInput.Icon icon="account-multiple-plus" />}
                />
                <Button
                  mode="outlined"
                  onPress={handleInviteFamily}
                  icon="send-outline"
                  style={styles.button}
                >
                  Invite Family to Group
                </Button>
              </Card.Content>
            </Card>
          )}
        </Card.Content>
      </Card>

      <Button
        mode="outlined"
        textColor="#f43f5e"
        onPress={handleLogout}
        icon="logout"
        style={styles.logoutBtn}
      >
        Logout Session
      </Button>
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
    paddingBottom: 48,
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
    marginTop: 12,
    marginBottom: 8,
  },
  card: {
    marginBottom: 16,
    backgroundColor: '#ffffff',
    borderRadius: 12,
  },
  nestedCard: {
    marginTop: 12,
    backgroundColor: '#f8fafc',
    borderRadius: 8,
  },
  cardGap: {
    gap: 10,
  },
  subTitle: {
    fontWeight: '700',
    color: '#334155',
  },
  subLabel: {
    color: '#64748b',
  },
  divider: {
    marginVertical: 4,
  },
  button: {
    borderRadius: 8,
    marginTop: 2,
  },
  chipRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  chip: {
    borderRadius: 20,
  },
  memberRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    paddingLeft: 12,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  memberInfo: {
    flex: 1,
  },
  memberName: {
    fontWeight: 'bold',
    color: '#1e293b',
  },
  memberRole: {
    color: '#64748b',
  },
  badge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    padding: 10,
    borderRadius: 8,
  },
  badgeSuccess: {
    backgroundColor: '#f0fdf4',
  },
  badgeWarning: {
    backgroundColor: '#fffbe3',
  },
  badgeText: {
    fontWeight: '700',
  },
  groupTitle: {
    fontWeight: 'bold',
    color: '#0f172a',
  },
  groupMeta: {
    color: '#64748b',
  },
  sourceText: {
    color: '#0369a1',
  },
  participantRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  participantText: {
    color: '#334155',
  },
  logoutBtn: {
    marginTop: 12,
    marginBottom: 24,
    borderColor: '#f43f5e',
    borderRadius: 8,
  },
});
