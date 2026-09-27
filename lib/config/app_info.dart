class AppInfo {
  static const String appName = 'Carpool Coordinator';

  /// Version specified in pubspec or passed via dart-define
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  /// Git Tag or Release Name injected at build time
  static const String gitTag = String.fromEnvironment(
    'GIT_TAG',
    defaultValue: 'Dev Build',
  );

  /// Git Commit SHA injected at build time
  static const String gitCommit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'Dev Build',
  );

  /// Build Timestamp injected at build time (e.g. ISO-8601 string)
  static const String buildDate = String.fromEnvironment(
    'BUILD_DATE',
    defaultValue: 'Dev Build',
  );

  /// Returns short commit hash (first 7 characters) if valid SHA, or raw value
  static String get shortGitCommit {
    if (gitCommit == 'Dev Build' || gitCommit.length < 7) {
      return gitCommit;
    }
    return gitCommit.substring(0, 7);
  }
}
