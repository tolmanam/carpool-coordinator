import { openDatabaseSync } from 'expo-sqlite';
import { drizzle } from 'drizzle-orm/expo-sqlite';
import * as schema from './schema';

export const expoDb = openDatabaseSync('carpool.db');
export const db = drizzle(expoDb, { schema });

// Helper to run raw migration or table creation commands during prototype / test
export function initDatabaseTables() {
  try {
    expoDb.execSync(`
      CREATE TABLE IF NOT EXISTS local_settings (
        key TEXT PRIMARY KEY NOT NULL,
        value TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS cached_families (
        matrix_id TEXT PRIMARY KEY NOT NULL,
        family_name TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address_text TEXT,
        last_updated INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS cached_family_members (
        member_id TEXT PRIMARY KEY NOT NULL,
        matrix_id TEXT NOT NULL,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        FOREIGN KEY (matrix_id) REFERENCES cached_families(matrix_id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS cached_schedules (
        schedule_id TEXT PRIMARY KEY NOT NULL,
        title TEXT NOT NULL,
        ical_feed_url TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        address_text TEXT
      );

      CREATE TABLE IF NOT EXISTS local_ical_events (
        id TEXT PRIMARY KEY NOT NULL,
        schedule_id TEXT NOT NULL,
        title TEXT NOT NULL,
        start_time INTEGER NOT NULL,
        end_time INTEGER NOT NULL,
        FOREIGN KEY (schedule_id) REFERENCES cached_schedules(schedule_id) ON DELETE CASCADE
      );

      CREATE TABLE IF NOT EXISTS cached_signups (
        id TEXT NOT NULL,
        schedule_id TEXT NOT NULL,
        event_timestamp INTEGER NOT NULL,
        member_id TEXT NOT NULL,
        role TEXT NOT NULL,
        status TEXT NOT NULL,
        PRIMARY KEY (schedule_id, event_timestamp, member_id)
      );

      CREATE TABLE IF NOT EXISTS cached_routes (
        id TEXT NOT NULL,
        schedule_id TEXT NOT NULL,
        event_timestamp INTEGER NOT NULL,
        driver_id TEXT NOT NULL,
        estimated_departure INTEGER NOT NULL,
        waypoints_json TEXT NOT NULL,
        route_polyline TEXT,
        PRIMARY KEY (schedule_id, event_timestamp)
      );
    `);
  } catch (error) {
    console.error('Failed to initialize local sqlite tables:', error);
  }
}
