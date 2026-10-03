/// Build-time configuration, passed with `--dart-define`.
abstract final class AppConfig {
  /// Android emulators reach the host machine at 10.0.2.2.
  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
