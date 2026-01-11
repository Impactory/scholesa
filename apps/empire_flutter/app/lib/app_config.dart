/// Environment configuration - single source of truth for app config.
/// Uses dart-define values passed at build time.
class AppConfig {
  /// Firebase project ID
  static const String firebaseProjectId = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
    defaultValue: 'scholesa-dev',
  );

  /// API base URL for Cloud Run backend
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Current environment: dev, staging, prod
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'dev',
  );

  /// Whether to enable debug logging
  static bool get isDebug => environment == 'dev';

  /// Whether to use Firebase emulators
  static const bool useEmulators = bool.fromEnvironment(
    'USE_EMULATORS',
  );

  /// Firestore emulator host
  static const String firestoreEmulatorHost = String.fromEnvironment(
    'FIRESTORE_EMULATOR_HOST',
    defaultValue: 'localhost:8080',
  );

  /// Auth emulator host
  static const String authEmulatorHost = String.fromEnvironment(
    'AUTH_EMULATOR_HOST',
    defaultValue: 'localhost:9099',
  );
}
