import React, { useEffect } from 'react';
import { Stack } from 'expo-router';
import { MD3LightTheme, PaperProvider } from 'react-native-paper';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import { initDatabaseTables } from '../db/client';

const theme = {
  ...MD3LightTheme,
  colors: {
    ...MD3LightTheme.colors,
    primary: '#1d4ed8',
    secondary: '#0284c7',
    tertiary: '#10b981',
    surfaceVariant: '#f1f5f9',
  },
};

export default function RootLayout() {
  useEffect(() => {
    // Initialize standard migrations or raw database tables natively on startup
    initDatabaseTables();
  }, []);

  return (
    <SafeAreaProvider>
      <PaperProvider theme={theme}>
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="index" />
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="route-active" options={{ presentation: 'modal' }} />
        </Stack>
      </PaperProvider>
    </SafeAreaProvider>
  );
}
