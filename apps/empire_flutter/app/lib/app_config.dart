import 'firebase_options.dart';

/// Environment configuration - single source of truth for app config.
/// Uses dart-define values passed at build time.
class AppConfig {
  /// Firebase project ID
  static const String _firebaseProjectIdOverride = String.fromEnvironment(
    'FIREBASE_PROJECT_ID',
  );

  static String get firebaseProjectId =>
      _firebaseProjectIdOverride.isNotEmpty
          ? _firebaseProjectIdOverride
          : DefaultFirebaseOptions.currentPlatform.projectId;

  /// API base URL for Cloud Functions backend
  static const String _apiBaseUrlOverride = String.fromEnvironment('API_BASE_URL');

  static String get apiBaseUrl =>
      _apiBaseUrlOverride.isNotEmpty
          ? _apiBaseUrlOverride
          : 'https://us-central1-$firebaseProjectId.cloudfunctions.net/apiV1';

  /// Current environment: dev, staging, prod
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'prod',
  );

  /// Whether to enable debug logging
  static bool get isDebug => environment == 'dev';

  /// Whether to use Firebase emulators
  static const bool useEmulators = bool.fromEnvironment(
    'USE_EMULATORS',
  );

  /// Effective emulator mode. Production always uses live Firebase.
  static bool get shouldUseEmulators => useEmulators && environment != 'prod';

  /// Provisioning API is optional. Keep Firestore-first by default for RC3.
  static const bool enableProvisioningApi = bool.fromEnvironment(
    'ENABLE_PROVISIONING_API',
    defaultValue: false,
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
