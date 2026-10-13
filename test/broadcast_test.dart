import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/providers/auth_provider.dart';
import 'package:student/providers/broadcast_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/ble_advertiser.dart';
import 'package:student/services/ble_packet.dart';
import 'package:student/services/rotating_token.dart';
import 'package:student/services/secure_store.dart';

final _secret = Uint8List.fromList(List<int>.generate(32, (i) => i));

class FakeAdvertiser implements BleAdvertiser {
  bool supported = true;
  bool permission = true;
  bool grantOnRequest = true;
  bool bluetoothOn = true;
  bool enableWorks = true;
  int requestCalls = 0;
  int enableCalls = 0;
  final List<String> started = [];
  int stops = 0;
  bool advertising = false;

  @override
  Future<bool> get isSupported async => supported;
  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<bool> requestPermission() async {
    requestCalls++;
    if (grantOnRequest) permission = true;
    return grantOnRequest;
  }

  @override
  Future<bool> enableBluetooth() async {
    enableCalls++;
    if (enableWorks) bluetoothOn = true;
    return enableWorks;
  }

  @override
  Future<AdvertiseResult> start(String serviceUuid) async {
    if (!permission) return AdvertiseResult.permissionDenied;
    if (!bluetoothOn) return AdvertiseResult.bluetoothOff;
    started.add(serviceUuid);
    advertising = true;
    return AdvertiseResult.ok;
  }

  @override
  Future<void> stop() async {
    stops++;
    advertising = false;
  }

  @override
  Future<void> openAppSettings() async {}
}

Future<AuthProvider> _signedIn({bool withSecret = true}) async {
  FlutterSecureStorage.setMockInitialValues({
    'token': 't',
    'user': jsonEncode({'id': 5, 'name': 'Omar', 'student_number': 10001}),
    if (withSecret) 'secret': base64Encode(_secret),
  });
  final auth = AuthProvider(ApiClient(client: MockClient((r) async => http.Response('{}', 200))), SecureStore());
  await auth.restore();
  return auth;
}

void main() {
  // counter 59000000 starts at second 1_770_000_000; start 7 s into the window.
  const windowStart = 59000000 * 30;
  late int now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    now = windowStart + 7;
  });

  Future<void> tick(BroadcastProvider b, int seconds) async {
    for (var i = 0; i < seconds; i++) {
      now++;
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  BroadcastProvider make(AuthProvider auth, FakeAdvertiser adv, {int session = 60}) =>
      BroadcastProvider(auth, advertiser: adv, clock: () => now, sessionSeconds: session, autoRun: false);

  test('not available without the secure code (feature off): nothing is broadcast', () async {
    final auth = await _signedIn(withSecret: false);
    final adv = FakeAdvertiser();
    final b = make(auth, adv);

    await b.start(userInitiated: true);

    expect(b.available, isFalse);
    expect(b.status, BroadcastStatus.idle);
    expect(adv.started, isEmpty);
    b.dispose();
  });

  test('starts advertising the packet for the shared test-vector window', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    now = windowStart + 7;
    final b = make(auth, adv);

    await b.start(userInitiated: true);

    expect(b.status, BroadcastStatus.active);
    expect(adv.started, hasLength(1));
    expect(adv.started.single, '4d530100-0027-11b4-a0fd-ce853f03dfc5');
    final parsed = BlePacket.parse(adv.started.single)!;
    expect(parsed.studentNo, 10001);
    expect(parsed.macHex, RotatingToken.hex(RotatingToken.mac(_secret, 10001, 59000000)));
    expect(b.secondsLeft, 60);
    await b.stop();
    b.dispose();
  });

  test('stop() takes the packet off the air', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    final b = make(auth, adv);

    await b.start(userInitiated: true);
    expect(adv.advertising, isTrue);
    await b.stop();

    expect(adv.advertising, isFalse);
    expect(b.status, BroadcastStatus.idle);
    b.dispose();
  });

  test('re-advertises a NEW packet when the 30 s code rotates, and stops after the session', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    now = windowStart + 25; // 5 s before the code rotates
    final b = make(auth, adv, session: 8);

    await b.start(userInitiated: true);
    final first = adv.started.single;

    await tick(b, 3); // still inside the window
    expect(adv.started, hasLength(1));

    await tick(b, 3); // crossed into the next window
    expect(adv.started.length, greaterThanOrEqualTo(2));
    final second = adv.started.last;
    expect(second, isNot(first));
    expect(BlePacket.parse(second)!.macHex,
        RotatingToken.hex(RotatingToken.mac(_secret, 10001, 59000001)));

    await tick(b, 3); // session length (8 s) is over
    expect(b.status, BroadcastStatus.idle);
    expect(adv.advertising, isFalse);
    b.dispose();
  });

  test('permission: a quiet auto-start asks once, then waits for the button', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser()
      ..permission = false
      ..grantOnRequest = false;
    final b = make(auth, adv);

    await b.start(); // first ever auto-start: asks
    expect(adv.requestCalls, 1);
    expect(b.status, BroadcastStatus.needsPermission);

    await b.start(); // later auto-start: must NOT nag
    expect(adv.requestCalls, 1);
    expect(b.status, BroadcastStatus.needsPermission);

    adv.grantOnRequest = true;
    await b.start(userInitiated: true); // the student taps the button
    expect(adv.requestCalls, 2);
    expect(b.status, BroadcastStatus.active);
    await b.stop();
    b.dispose();
  });

  test('Bluetooth off: auto-start reports it, the button asks to turn it on', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser()..bluetoothOn = false;
    final b = make(auth, adv);

    await b.start();
    expect(b.status, BroadcastStatus.bluetoothOff);
    expect(adv.enableCalls, 0);

    await b.start(userInitiated: true);
    expect(adv.enableCalls, 1);
    expect(b.status, BroadcastStatus.active);
    await b.stop();
    b.dispose();
  });

  test('Bluetooth off and the student declines to turn it on', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser()
      ..bluetoothOn = false
      ..enableWorks = false;
    final b = make(auth, adv);

    await b.start(userInitiated: true);

    expect(b.status, BroadcastStatus.bluetoothOff);
    expect(adv.advertising, isFalse);
    b.dispose();
  });

  test('phone without Bluetooth LE advertising: clear unsupported state', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser()..supported = false;
    final b = make(auth, adv);

    await b.start(userInitiated: true);

    expect(b.status, BroadcastStatus.unsupported);
    expect(adv.started, isEmpty);
    b.dispose();
  });

  test('going to the background stops the broadcast; coming back is a fresh session', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    final b = BroadcastProvider(auth, advertiser: adv, clock: () => now, autoRun: true);

    b.onForeground(); // auto-starts (permission already granted)
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.active);

    b.onBackground();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.idle);
    expect(adv.advertising, isFalse);

    b.onForeground();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.active);
    expect(b.secondsLeft, 60);
    await b.stop();
    b.dispose();
  });

  test('auto-start waits while another permission prompt is on screen, then goes ahead', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    final b = BroadcastProvider(auth, advertiser: adv, clock: () => now, autoRun: true)..holdAutoStart = true;

    b.onForeground();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.idle);
    expect(adv.started, isEmpty);

    b.holdAutoStart = false;
    b.onForeground();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.active);
    await b.stop();
    b.dispose();
  });

  test('logging out stops the broadcast', () async {
    final auth = await _signedIn();
    final adv = FakeAdvertiser();
    final b = BroadcastProvider(auth, advertiser: adv, clock: () => now, autoRun: true);
    b.onForeground();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(b.status, BroadcastStatus.active);

    await auth.logout();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(b.status, BroadcastStatus.idle);
    expect(adv.advertising, isFalse);
    b.dispose();
  });
}
