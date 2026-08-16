import React from 'react';
import { StyleSheet, View } from 'react-native';
import { Text, Button, Card, Icon, useTheme } from 'react-native-paper';

interface EmptyStateProps {
  icon: string;
  title: string;
  description: string;
  buttonText?: string;
  onButtonPress?: () => void;
}

export default function EmptyState({
  icon,
  title,
  description,
  buttonText,
  onButtonPress,
}: EmptyStateProps) {
  const theme = useTheme();

  return (
    <Card style={styles.card} mode="elevated">
      <Card.Content style={styles.content}>
        <View style={[styles.iconContainer, { backgroundColor: theme.colors.surfaceVariant }]}>
          <Icon source={icon} size={40} color={theme.colors.primary} />
        </View>

        <Text variant="titleMedium" style={styles.title}>
          {title}
        </Text>

        <Text variant="bodyMedium" style={styles.description}>
          {description}
        </Text>

        {buttonText && onButtonPress && (
          <Button
            mode="contained"
            onPress={onButtonPress}
            style={styles.button}
            icon="plus"
          >
            {buttonText}
          </Button>
        )}
      </Card.Content>
    </Card>
  );
}

const styles = StyleSheet.create({
  card: {
    marginVertical: 16,
    borderRadius: 16,
    backgroundColor: '#ffffff',
  },
  content: {
    alignItems: 'center',
    paddingVertical: 24,
    paddingHorizontal: 16,
  },
  iconContainer: {
    width: 64,
    height: 64,
    borderRadius: 32,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: 16,
  },
  title: {
    fontWeight: 'bold',
    textAlign: 'center',
    color: '#0f172a',
    marginBottom: 6,
  },
  description: {
    textAlign: 'center',
    color: '#64748b',
    marginBottom: 16,
    paddingHorizontal: 12,
  },
  button: {
    borderRadius: 8,
    marginTop: 8,
  },
});
