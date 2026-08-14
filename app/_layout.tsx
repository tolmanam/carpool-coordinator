import React, { useEffect } from 'react';
import { Stack } from 'expo-router';
import { initDatabaseTables } from '../db/client';

export default function RootLayout() {
  useEffect(() => {
    // Initialize standard migrations or raw database tables natively on startup
    initDatabaseTables();
  }, []);

  return (
    <Stack screenOptions={{ headerShown: false }}>
      <Stack.Screen name="index" />
      <Stack.Screen name="(tabs)" />
      <Stack.Screen name="route-active" options={{ presentation: 'modal' }} />
    </Stack>
  );
}
