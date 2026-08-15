import { MD3LightTheme } from 'react-native-paper';

describe('Material Design Theme & Material-UI Setup', () => {
  it('should define valid MD3 Light Theme properties', () => {
    expect(MD3LightTheme).toBeDefined();
    expect(MD3LightTheme.version).toBe(3);
    expect(MD3LightTheme.colors).toHaveProperty('primary');
    expect(MD3LightTheme.colors).toHaveProperty('surface');
    expect(MD3LightTheme.colors).toHaveProperty('onPrimary');
  });

  it('should customize primary theme colors for Carpool Coordinator brand', () => {
    const customTheme = {
      ...MD3LightTheme,
      colors: {
        ...MD3LightTheme.colors,
        primary: '#1d4ed8',
        secondary: '#0284c7',
        tertiary: '#10b981',
      },
    };

    expect(customTheme.colors.primary).toBe('#1d4ed8');
    expect(customTheme.colors.secondary).toBe('#0284c7');
    expect(customTheme.colors.tertiary).toBe('#10b981');
  });
});
