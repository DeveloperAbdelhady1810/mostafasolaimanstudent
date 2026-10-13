# Mostafa Solaiman – Student app

Flutter app (Android + iOS) for students of mostafa-solaiman.online.
Package / bundle id: `online.mostafasolaiman.student`. English + Arabic (RTL), website colours.

## What it does

- **Sign in** with email or phone + password (same rules as the website). Signing in needs internet.
- **Stays signed in and works fully offline** afterwards: the student ID and the QR code are computed on the phone.
- **Rotating QR** (`MSQ1:<student_no>:<counter>:<mac>`, changes every 30 s, HMAC-SHA256 with a per-student secret
  fetched once after sign-in). While the server feature flag is off, it shows the plain `LQ-######` ID code that the
  existing assistant app already scans.
- **Continue with Google / Apple** (same as the website): the phone signs in natively and sends the provider's identity
  token to the server, which verifies it itself (signature, issuer, audience, expiry; Apple also checks a one-time nonce).
  An email that already has a student account is signed in; a new email opens the same profile form as the website's
  sign-up (stage, grade, division, study mode / Zoom group, school, gender, age, phone, parent phone) and the server creates the
  student + parent record. Teacher/parent/admin emails and suspended students are refused. Apple's button is shown on iPhone only.
- **Attendance** history and **notifications**, cached for offline viewing, refreshed when online.
- **Push notifications** (Firebase Cloud Messaging), e.g. "your attendance was recorded".

- **Bluetooth check-in** (only when the secure code is on): the phone broadcasts the same rotating code for 60 s
  (restart with "Broadcast again"), so the assistant's Classroom Radar can detect the whole class at once. Works with no
  internet. The packet is one 128-bit service UUID: `0x4D53 | version 1 | student_no (4 bytes) | MAC (9 bytes)`.
- **Reply tick**: while broadcasting, the phone also listens for the assistant's "I heard you" reply
  (`0x4D41 | 1 | student_no | the MAC it heard`). It only counts if it echoes one of THIS phone's own recent codes, so a
  stranger's phone cannot fake it. Plays a chime and shows "Assistant scanned you successfully" (works offline).
  The push "attendance recorded" shows the same banner once the assistant confirms on the server.

Android 11 and older need Location permission (and Location switched on) for Bluetooth scanning; Android 12+ and iOS only
ask for Bluetooth ("Nearby devices"). iPhones broadcast only while the app is open on screen.

## Layout

```
lib/
  main.dart                 app wiring, session restore, lifecycle sync
  config.dart               API base URL, code window
  theme.dart                website palette (emerald #059669 / sky #0EA5E9)
  l10n/strings.dart         English + Arabic texts
  models.dart, utils.dart
  providers/                auth (session + secret), code (1 s ticker), data (cache + connectivity), locale, nav,
                            broadcast (Bluetooth), ack (reply tick + banner)
  services/                 api_client, secure_store (encrypted), rotating_token (HMAC), push_service (FCM),
                            ble_packet, ble_advertiser, reply_scanner, tick_player
  screens/                  login, home, attendance, notifications, settings, shell
test/                       token test vector, offline restore, login errors, RTL, UTC time parsing
```

## Server endpoints used

`POST /api/auth/student-login`, `POST /api/student/ble/secret`, `GET /api/student/attendance`,
`GET /api/notifications` (+ read / mark-all-read), `POST|DELETE /api/device-token`, `POST /api/auth/logout`.

The token algorithm must stay byte-identical to the server's `App\Services\BleToken`;
`test/rotating_token_test.dart` holds the shared test vector.

## Build

```
flutter pub get
flutter analyze && flutter test
flutter build apk            # Android (add your release keystore first)
```

Test builds against a local mock server (never ship these): `--dart-define=API_BASE=http://10.0.2.2:8765/api`
(debug builds allow cleartext http for this; release builds are https-only).

Firebase is initialised from `lib/firebase_options.dart` (explicit options), so no Gradle Google-services plugin or
`GoogleService-Info.plist` build step is needed. **That file is git-ignored and is not in this repo**: copy
`lib/firebase_options.dart.example` to `lib/firebase_options.dart` and fill in the values from the Firebase console
(or copy the real file from the machine that has it). The push service-account key is never part of this repo; it
lives only on the server. Signing keys, `.env` files and API keys must never be committed.

### Google / Apple sign-in setup

Server (already deployed): `POST /api/auth/social/{google,apple,complete}`, `GET /api/auth/social/{config,options}`.
Google tokens are accepted for the website's web client id (`GOOGLE_CLIENT_ID`) and, optionally, a dedicated
`GOOGLE_MOBILE_SERVER_CLIENT_ID` / `GOOGLE_MOBILE_CLIENT_IDS` in the server `.env`; Apple tokens for the bundle id
`online.mostafasolaiman.student` (`APPLE_MOBILE_CLIENT_ID`).

- **Android**: the Android OAuth client (package + SHA-1) must live in the SAME Google Cloud project as the web client id the
  server hands out. Easiest: Firebase console > Authentication > Sign-in method > enable Google, then add the SHA-1 of every
  keystore you build with (debug on each machine, release, and Play App Signing) in Project settings > your Android app.
  Debug SHA-1: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android`.
- **iOS Google**: copy `ios/Flutter/Secrets.xcconfig.example` to `ios/Flutter/Secrets.xcconfig` (git-ignored) and fill in
  `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_REVERSED_CLIENT_ID` (from the iOS OAuth client / the new GoogleService-Info.plist).
- **iOS Apple**: `Runner.entitlements` already has `com.apple.developer.applesignin`; enable the "Sign In with Apple"
  capability for the App ID in the Apple developer portal / Xcode (Signing & Capabilities).

### iOS (needs a Mac)

1. Firebase console → Project settings → Cloud Messaging: upload the APNs auth key (.p8).
2. Xcode → Runner → Signing & Capabilities: add **Push Notifications** and **Background Modes → Remote notifications**.
3. `cd ios && pod install`, then run/archive.

### Android release

Create a keystore, add `android/key.properties`, and point `signingConfigs.release` in
`android/app/build.gradle.kts` at it (the release build currently falls back to the debug key).
