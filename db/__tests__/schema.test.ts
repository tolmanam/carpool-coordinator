import { localSettings, cachedFamilies, cachedFamilyMembers, cachedSchedules, localIcalEvents } from '../schema';

describe('SQLite Drizzle Schema Definition Tests', () => {
  it('correctly defines localSettings table', () => {
    expect(localSettings.key.name).toBe('key');
    expect(localSettings.value.name).toBe('value');
  });

  it('correctly defines cachedFamilies table with lat/lng attributes', () => {
    expect(cachedFamilies.matrixId.name).toBe('matrix_id');
    expect(cachedFamilies.familyName.name).toBe('family_name');
    expect(cachedFamilies.latitude.name).toBe('latitude');
    expect(cachedFamilies.longitude.name).toBe('longitude');
  });

  it('correctly defines localIcalEvents table with references', () => {
    expect(localIcalEvents.id.name).toBe('id');
    expect(localIcalEvents.scheduleId.name).toBe('schedule_id');
    expect(localIcalEvents.startTime.name).toBe('start_time');
    expect(localIcalEvents.endTime.name).toBe('end_time');
  });
});
