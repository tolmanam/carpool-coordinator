import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  ScrollView,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
} from 'react-native';
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
  syncMultipleIcalFeeds,
} from '../../utils/matrixClient';
import { eq } from 'drizzle-orm';

export default function SettingsScreen() {
  const router = useRouter();
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
      const theme = await getThemeMode();
      setThemeModeState(theme);

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

  const handleSaveTheme = async (theme: 'light' | 'dark' | 'system') => {
    setThemeModeState(theme);
    await setThemeMode(theme);
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
        <ActivityIndicator size="large" color="#2563eb" />
      </View>
    );
  }

  return (
    <ScrollView style={styles.container}>
      {/* 1. System Configuration */}
      <Text style={styles.sectionTitle}>1. System Configuration</Text>
      <View style={styles.section}>
        <Text style={styles.label}>Matrix Username</Text>
        <TextInput
          style={styles.input}
          value={username}
          onChangeText={setUsername}
          placeholder="@username:matrix.org"
          autoCapitalize="none"
        />

        <Text style={styles.label}>Matrix Homeserver URL</Text>
        <TextInput
          style={styles.input}
          value={homeserver}
          onChangeText={setHomeserver}
          placeholder="https://matrix.org"
          autoCapitalize="none"
        />

        <TouchableOpacity
          style={styles.primaryBtn}
          onPress={handleReauthenticate}
          disabled={processing}
        >
          {processing ? (
            <ActivityIndicator size="small" color="#fff" />
          ) : (
            <Text style={styles.primaryBtnText}>Re-authenticate Matrix & Clear Cache</Text>
          )}
        </TouchableOpacity>

        <Text style={[styles.label, { marginTop: 16 }]}>Notification Sound</Text>
        <View style={styles.rowSelector}>
          {['default', 'chime', 'bell', 'mute'].map((snd) => (
            <TouchableOpacity
              key={snd}
              style={[
                styles.chip,
                notificationSound === snd && styles.chipActive,
              ]}
              onPress={() => handleSaveSound(snd)}
            >
              <Text
                style={[
                  styles.chipText,
                  notificationSound === snd && styles.chipTextActive,
                ]}
              >
                {snd.toUpperCase()}
              </Text>
            </TouchableOpacity>
          ))}
        </View>

        <Text style={[styles.label, { marginTop: 16 }]}>Dark Mode / Theme</Text>
        <View style={styles.rowSelector}>
          {(['light', 'dark', 'system'] as const).map((thm) => (
            <TouchableOpacity
              key={thm}
              style={[
                styles.chip,
                themeMode === thm && styles.chipActive,
              ]}
              onPress={() => handleSaveTheme(thm)}
            >
              <Text
                style={[
                  styles.chipText,
                  themeMode === thm && styles.chipTextActive,
                ]}
              >
                {thm.toUpperCase()}
              </Text>
            </TouchableOpacity>
          ))}
        </View>
      </View>

      {/* 2. Profile Configuration */}
      <Text style={styles.sectionTitle}>2. Profile Configuration</Text>
      <View style={styles.section}>
        <Text style={styles.label}>My Roles (Multi-Select)</Text>
        <Text style={styles.subLabel}>
          Roles are synchronized to Matrix and visible to your family and carpool groups.
        </Text>

        <View style={styles.rowSelector}>
          {['Parent', 'Driver', 'Participant'].map((role) => {
            const active = userRoles.includes(role);
            return (
              <TouchableOpacity
                key={role}
                style={[styles.chip, active && styles.chipActive]}
                onPress={() => toggleUserRole(role)}
              >
                <Text style={[styles.chipText, active && styles.chipTextActive]}>
                  {active ? `✓ ${role}` : role}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>
      </View>

      {/* 3. Family Group Configuration */}
      <Text style={styles.sectionTitle}>3. Family Group Configuration</Text>
      <View style={styles.section}>
        <Text style={styles.label}>Family Name</Text>
        <TextInput
          style={styles.input}
          value={familyName}
          onChangeText={setFamilyName}
          placeholder="e.g. The Smith Family"
        />
        <TouchableOpacity style={styles.secondaryBtn} onPress={handleSaveFamilyName}>
          <Text style={styles.secondaryBtnText}>Save Family Name</Text>
        </TouchableOpacity>

        <Text style={[styles.label, { marginTop: 16 }]}>Family Members</Text>
        {members.map((m) => {
          let rolesStr = m.role;
          if (rolesStr.startsWith('[')) {
            try {
              rolesStr = JSON.parse(rolesStr).join(', ');
            } catch {}
          }
          return (
            <View key={m.memberId} style={styles.memberRow}>
              <View>
                <Text style={styles.memberName}>{m.name}</Text>
                <Text style={styles.memberRole}>Roles: {rolesStr}</Text>
              </View>
              <TouchableOpacity
                style={styles.deleteBtn}
                onPress={() => handleRemoveMember(m.memberId)}
              >
                <Text style={styles.deleteBtnText}>Remove</Text>
              </TouchableOpacity>
            </View>
          );
        })}

        <Text style={[styles.label, { marginTop: 16 }]}>Add Family Member</Text>
        <TextInput
          style={styles.input}
          value={newMemberName}
          onChangeText={setNewMemberName}
          placeholder="Member Name (e.g. Sarah)"
        />
        <Text style={styles.subLabel}>Assign Roles:</Text>
        <View style={styles.rowSelector}>
          {['Parent', 'Driver', 'Participant'].map((role) => {
            const active = newMemberRoles.includes(role);
            return (
              <TouchableOpacity
                key={role}
                style={[styles.chip, active && styles.chipActive]}
                onPress={() => toggleNewMemberRole(role)}
              >
                <Text style={[styles.chipText, active && styles.chipTextActive]}>
                  {active ? `✓ ${role}` : role}
                </Text>
              </TouchableOpacity>
            );
          })}
        </View>

        <TouchableOpacity style={[styles.secondaryBtn, { marginTop: 12 }]} onPress={handleAddMember}>
          <Text style={styles.secondaryBtnText}>Add Family Member</Text>
        </TouchableOpacity>
      </View>

      {/* 4. Carpool Group Configuration */}
      <Text style={styles.sectionTitle}>4. Carpool Group Configuration</Text>
      <View style={styles.section}>
        <View style={styles.badgeRow}>
          <Text style={isParent ? styles.badgeSuccess : styles.badgeWarning}>
            {isParent ? '✓ Parent Role Active (Can Create Groups)' : '⚠️ Parent Role Required to Create Groups'}
          </Text>
        </View>

        <Text style={styles.label}>Create Carpool Group</Text>
        <TextInput
          style={styles.input}
          value={newGroupName}
          onChangeText={setNewGroupName}
          placeholder="Group Title (e.g. Swim Club Commute)"
        />
        <TextInput
          style={styles.input}
          value={newEventSource}
          onChangeText={setNewEventSource}
          placeholder="Primary iCal Feed URL (.ics)"
          autoCapitalize="none"
        />
        <TouchableOpacity
          style={[styles.primaryBtn, !isParent && styles.btnDisabled]}
          onPress={handleCreateGroup}
          disabled={!isParent || processing}
        >
          <Text style={styles.primaryBtnText}>Create Carpool Group</Text>
        </TouchableOpacity>

        {schedules.length > 0 && (
          <>
            <Text style={[styles.label, { marginTop: 20 }]}>Select Carpool Group to Manage</Text>
            <View style={styles.rowSelector}>
              {schedules.map((sch) => {
                const isSelected = selectedScheduleId === sch.scheduleId;
                return (
                  <TouchableOpacity
                    key={sch.scheduleId}
                    style={[styles.chip, isSelected && styles.chipActive]}
                    onPress={() => setSelectedScheduleId(sch.scheduleId)}
                  >
                    <Text style={[styles.chipText, isSelected && styles.chipTextActive]}>
                      {sch.title}
                    </Text>
                  </TouchableOpacity>
                );
              })}
            </View>
          </>
        )}

        {selectedGroup && (
          <View style={styles.groupDetailCard}>
            <Text style={styles.groupTitle}>Manage: {selectedGroup.title}</Text>
            <Text style={styles.groupMeta}>
              Owner: {selectedGroup.ownerId || matrixId}
            </Text>

            <Text style={[styles.label, { marginTop: 12 }]}>Event Sources (iCal Feeds)</Text>
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
                <Text key={idx} style={styles.sourceText}>
                  • {src}
                </Text>
              ));
            })()}

            <TextInput
              style={[styles.input, { marginTop: 8 }]}
              value={additionalFeedUrl}
              onChangeText={setAdditionalFeedUrl}
              placeholder="Add another iCal feed URL (.ics)"
              autoCapitalize="none"
            />
            <TouchableOpacity style={styles.secondaryBtn} onPress={handleAddEventSource}>
              <Text style={styles.secondaryBtnText}>Add iCal Feed (Owner Only)</Text>
            </TouchableOpacity>

            <Text style={[styles.label, { marginTop: 16 }]}>Group Participants</Text>
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
                  <Text style={styles.participantText}>{partId}</Text>
                  <TouchableOpacity
                    style={styles.deleteBtn}
                    onPress={() => handleRemoveParticipant(partId)}
                  >
                    <Text style={styles.deleteBtnText}>
                      {partId === matrixId ? 'Leave Group' : 'Remove'}
                    </Text>
                  </TouchableOpacity>
                </View>
              ));
            })()}

            <TextInput
              style={[styles.input, { marginTop: 8 }]}
              value={inviteFamilyId}
              onChangeText={setInviteFamilyId}
              placeholder="Invite Family (@username:matrix.org)"
              autoCapitalize="none"
            />
            <TouchableOpacity style={styles.secondaryBtn} onPress={handleInviteFamily}>
              <Text style={styles.secondaryBtnText}>Invite Family to Group</Text>
            </TouchableOpacity>
          </View>
        )}
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
    color: '#334155',
    marginBottom: 6,
  },
  subLabel: {
    fontSize: 12,
    color: '#64748b',
    marginBottom: 8,
  },
  input: {
    borderWidth: 1,
    borderColor: '#cbd5e1',
    borderRadius: 8,
    padding: 10,
    fontSize: 14,
    backgroundColor: '#f8fafc',
    marginBottom: 10,
  },
  primaryBtn: {
    backgroundColor: '#2563eb',
    padding: 12,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 4,
  },
  primaryBtnText: {
    color: '#fff',
    fontWeight: 'bold',
    fontSize: 14,
  },
  secondaryBtn: {
    backgroundColor: '#0284c7',
    padding: 10,
    borderRadius: 8,
    alignItems: 'center',
  },
  secondaryBtnText: {
    color: '#fff',
    fontWeight: '600',
    fontSize: 13,
  },
  btnDisabled: {
    backgroundColor: '#94a3b8',
  },
  rowSelector: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
    marginBottom: 8,
  },
  chip: {
    paddingVertical: 6,
    paddingHorizontal: 12,
    borderRadius: 16,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    backgroundColor: '#f1f5f9',
  },
  chipActive: {
    backgroundColor: '#2563eb',
    borderColor: '#2563eb',
  },
  chipText: {
    fontSize: 12,
    fontWeight: '600',
    color: '#475569',
  },
  chipTextActive: {
    color: '#fff',
  },
  memberRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    backgroundColor: '#f8fafc',
    padding: 10,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#e2e8f0',
    marginBottom: 8,
  },
  memberName: {
    fontSize: 14,
    fontWeight: 'bold',
    color: '#1e293b',
  },
  memberRole: {
    fontSize: 12,
    color: '#64748b',
  },
  deleteBtn: {
    backgroundColor: '#fecdd3',
    paddingVertical: 4,
    paddingHorizontal: 10,
    borderRadius: 6,
  },
  deleteBtnText: {
    color: '#e11d48',
    fontSize: 12,
    fontWeight: 'bold',
  },
  badgeRow: {
    marginBottom: 12,
  },
  badgeSuccess: {
    backgroundColor: '#f0fdf4',
    borderColor: '#bbf7d0',
    borderWidth: 1,
    color: '#16a34a',
    padding: 8,
    borderRadius: 6,
    fontWeight: 'bold',
    fontSize: 12,
  },
  badgeWarning: {
    backgroundColor: '#fffbe3',
    borderColor: '#fde047',
    borderWidth: 1,
    color: '#b45309',
    padding: 8,
    borderRadius: 6,
    fontWeight: 'bold',
    fontSize: 12,
  },
  groupDetailCard: {
    backgroundColor: '#f8fafc',
    borderRadius: 8,
    padding: 12,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    marginTop: 16,
  },
  groupTitle: {
    fontSize: 15,
    fontWeight: 'bold',
    color: '#0f172a',
  },
  groupMeta: {
    fontSize: 12,
    color: '#64748b',
    marginBottom: 8,
  },
  sourceText: {
    fontSize: 12,
    color: '#0369a1',
    marginBottom: 4,
  },
  participantRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  participantText: {
    fontSize: 13,
    color: '#334155',
  },
  logoutBtn: {
    borderColor: '#f43f5e',
    borderWidth: 1.5,
    padding: 14,
    borderRadius: 8,
    alignItems: 'center',
    marginTop: 12,
    marginBottom: 48,
  },
  logoutBtnText: {
    color: '#f43f5e',
    fontWeight: 'bold',
    fontSize: 15,
  },
});
