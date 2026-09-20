/// Server base URL. Override at build/run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
/// (10.0.2.2 is the Android emulator's alias for the host machine's localhost.)
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3001',
);
