/// Server base URL. Defaults to production. Override for local dev with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3001
/// (10.0.2.2 is the Android emulator's alias for the host machine's localhost —
/// use your machine's LAN IP instead when testing on a physical device.)
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://tutoria.abubakarmunir.dev',
);
