/// Server the app talks to.
/// Overridable at build time for test builds: `--dart-define=API_BASE=http://10.0.2.2:8765/api`.
const String apiBaseUrl = String.fromEnvironment('API_BASE', defaultValue: 'https://mostafa-solaiman.online/api');
const String siteUrl = 'https://mostafa-solaiman.online';

/// QR format the assistant app already understands (see attendance_assistant's
/// config.dart). Used as the fallback while the rotating code is not available.
const String legacyQrPrefix = 'LQ-';

/// The rotating code changes every this many seconds (must match the server's BleToken).
const int codeWindowSeconds = 30;

const String appVersionLabel = '1.0.0';
