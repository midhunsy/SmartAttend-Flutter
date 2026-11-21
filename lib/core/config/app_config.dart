class AppConfig {
  const AppConfig._();

  static const String appName = 'SmartAttend';
  static const String apiBaseUrl = String.fromEnvironment(
    'SMARTATTEND_API_BASE_URL',
    defaultValue: 'https://smartattenddd.onrender.com',
  );
}
