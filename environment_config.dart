/// A class to manage environment-specific configurations.
///
/// Values are provided at compile time using the `--dart-define` flag.
/// Example: flutter run --dart-define=API_URL=https://api.production.com
class EnvironmentConfig {
  /// The base URL for the API.
  ///
  /// Defaults to a development URL if not provided.
  static const apiUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'https://api.dev.scholesa.com',
  );
}