import React, { useState } from 'react';
import { StyleSheet, View } from 'react-native';
import { Modal, Portal, Text, Button, Card, Icon, useTheme } from 'react-native-paper';

interface OnboardingModalProps {
  visible: boolean;
  onDismiss: () => void;
}

const ONBOARDING_STEPS = [
  {
    icon: 'home-heart',
    title: 'Welcome to Carpool Coordinator',
    description:
      'Organize school, sports, and team commutes with your family and trusted circles with zero backend servers.',
  },
  {
    icon: 'calendar-sync',
    title: 'Sync Activity Schedules',
    description:
      'Import iCal calendar feeds from your school or club. Sign up to ride or volunteer to drive with a single tap.',
  },
  {
    icon: 'shield-lock',
    title: 'Decentralized & Encrypted',
    description:
      'Powered by Matrix E2EE. Your child names, family addresses, and locations remain private and encrypted.',
  },
];

export default function OnboardingModal({ visible, onDismiss }: OnboardingModalProps) {
  const theme = useTheme();
  const [stepIndex, setStepIndex] = useState(0);

  const currentStep = ONBOARDING_STEPS[stepIndex];

  const handleNext = () => {
    if (stepIndex < ONBOARDING_STEPS.length - 1) {
      setStepIndex(stepIndex + 1);
    } else {
      setStepIndex(0);
      onDismiss();
    }
  };

  return (
    <Portal>
      <Modal visible={visible} onDismiss={onDismiss} contentContainerStyle={styles.modalContainer}>
        <Card style={styles.card}>
          <Card.Content style={styles.cardContent}>
            <View style={[styles.iconBox, { backgroundColor: theme.colors.surfaceVariant }]}>
              <Icon source={currentStep.icon} size={48} color={theme.colors.primary} />
            </View>

            <Text variant="titleLarge" style={styles.title}>
              {currentStep.title}
            </Text>

            <Text variant="bodyMedium" style={styles.description}>
              {currentStep.description}
            </Text>

            <View style={styles.dotsRow}>
              {ONBOARDING_STEPS.map((_, idx) => (
                <View
                  key={idx}
                  style={[
                    styles.dot,
                    idx === stepIndex
                      ? [styles.activeDot, { backgroundColor: theme.colors.primary }]
                      : styles.inactiveDot,
                  ]}
                />
              ))}
            </View>

            <View style={styles.buttonRow}>
              <Button mode="text" onPress={onDismiss}>
                Skip
              </Button>
              <Button mode="contained" onPress={handleNext} style={styles.nextBtn}>
                {stepIndex === ONBOARDING_STEPS.length - 1 ? 'Get Started' : 'Next'}
              </Button>
            </View>
          </Card.Content>
        </Card>
      </Modal>
    </Portal>
  );
}

const styles = StyleSheet.create({
  modalContainer: {
    padding: 20,
  },
  card: {
    borderRadius: 16,
    backgroundColor: '#ffffff',
  },
  cardContent: {
    alignItems: 'center',
    padding: 24,
  },
  iconBox: {
    width: 80,
    height: 80,
    borderRadius: 40,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 20,
  },
  title: {
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#0f172a',
    marginBottom: 8,
  },
  description: {
    textAlign: 'center',
    color: '#64748b',
    marginBottom: 24,
    lineHeight: 20,
  },
  dotsRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 24,
  },
  dot: {
    height: 8,
    borderRadius: 4,
  },
  activeDot: {
    width: 24,
  },
  inactiveDot: {
    width: 8,
    backgroundColor: '#cbd5e1',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    alignItems: 'center',
  },
  nextBtn: {
    borderRadius: 8,
  },
});
