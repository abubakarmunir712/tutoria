/// Server base URL. Defaults to production. For local debugging run `scripts/dev up`, which
/// writes this machine's current IP to app/dart_defines.local.json, then launch with
///   flutter run --dart-define-from-file=dart_defines.local.json
/// (the "Tutoria (local server)" launch configuration in VS Code does exactly this).
/// Or set it by hand: --dart-define=API_BASE_URL=http://10.0.2.2:3001 on the Android emulator
/// (10.0.2.2 is its alias for this machine's localhost), the machine's LAN IP on a real phone.
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://tutoria.abubakarmunir.dev',
);
