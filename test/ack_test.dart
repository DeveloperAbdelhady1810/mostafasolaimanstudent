import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student/main.dart';
import 'package:student/providers/ack_provider.dart';
import 'package:student/providers/auth_provider.dart';
import 'package:student/providers/locale_provider.dart';
import 'package:student/services/api_client.dart';
import 'package:student/services/ble_advertiser.dart';
import 'package:student/services/ble_packet.dart';
import 'package:student/services/reply_scanner.dart';
import 'package:student/services/rotating_token.dart';
import 'package:student/services/secure_store.dart';
import 'package:student/services/tick_player.dart';

final _secret = Uint8List.fromList(List<int>.generate(32, (i) => i));
const _windowStart = 59000000 * 30;

class FakeReplyScanner implements ReplyScanner {
  final _c = StreamController<List<String>>.broadcast();
  bool running = false;
  int starts = 0;
  bool startWorks = true;

  @override
  Stream<List<String>> get adverts => _c.stream;
  @override
  Future<bool> start() async {
    starts++;
    running = startWorks;
    return startWorks;
  }

  @override
  Future<void> stop() async => running = false;

  void hear(List<String> uuids) => _c.add(uuids);
}

class FakePlayer implements TickPlayer {
  int plays = 0;
  @override
  Future<void> play() async => plays++;
}

class FakeAdvertiser implements BleAdvertiser {
  @override
  Future<bool> get isSupported async => true;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<bool> enableBluetooth() async => true;
  @override
  Future<AdvertiseResult> start(String serviceUuid) async => AdvertiseResult.ok;
  @override
  Future<void> stop() async {}
  @override
  Future<void> openAppSettings() async {}
}

Future<AuthProvider> _signedIn() async {
  FlutterSecureStorage.setMockInitialValues({
    'token': 't',
    'user': jsonEncode({'id': 5, 'name': 'Omar', 'student_number': 10001}),
    'secret': base64Encode(_secret),
  });
  final auth = AuthProvider(ApiClient(client: MockClient((r) async => http.Response('{}', 200))), SecureStore());
  await auth.restore();
  return auth;
}

String _macFor(int studentNo, int counter) => RotatingToken.hex(RotatingToken.mac(_secret, studentNo, counter));
String _reply(int studentNo, String mac) => BlePacket.bytesToUuid(BlePacket.reply(studentNo, _hex(mac)));
List<int> _hex(String h) => List<int>.generate(h.length ~/ 2, (i) => int.parse(h.substring(i * 2, i * 2 + 2), radix: 16));
Future<void> _settle([int ms = 30]) => Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AckProvider', () {
    late FakeReplyScanner scanner;
    late FakePlayer player;
    late AckProvider ack;

    Future<AckProvider> make() async {
      final auth = await _signedIn();
      return AckProvider(auth,
          scanner: scanner, player: player, clock: () => _windowStart + 7, bannerDuration: const Duration(milliseconds: 200));
    }

    setUp(() {
      scanner = FakeReplyScanner();
      player = FakePlayer();
    });

    test('listens only while told to (i.e. while broadcasting)', () async {
      ack = await make();
      expect(scanner.running, isFalse);

      await ack.setListening(true);
      expect(scanner.running, isTrue);
      expect(ack.isListening, isTrue);

      await ack.setListening(false);
      expect(scanner.running, isFalse);
      ack.dispose();
    });

    test('the assistant\'s reply to MY current code shows the banner and plays the tick', () async {
      ack = await make();
      await ack.setListening(true);

      scanner.hear([_reply(10001, _macFor(10001, 59000000))]);
      await _settle();

      expect(ack.banner, AckKind.heard);
      expect(player.plays, 1);
      ack.dispose();
    });

    test('a reply to my code from the previous window (assistant was slow) still counts', () async {
      ack = await make();
      await ack.setListening(true);

      scanner.hear([_reply(10001, _macFor(10001, 58999999))]);
      await _settle();

      expect(ack.banner, AckKind.heard);
      ack.dispose();
    });

    test('a forged reply (right student, wrong code) is ignored', () async {
      ack = await make();
      await ack.setListening(true);

      scanner.hear([_reply(10001, '00112233445566778899'.substring(0, 18))]);
      await _settle();

      expect(ack.banner, isNull);
      expect(player.plays, 0);
      ack.dispose();
    });

    test('a reply meant for ANOTHER student is ignored', () async {
      ack = await make();
      await ack.setListening(true);

      scanner.hear([_reply(10002, _macFor(10002, 59000000))]);
      await _settle();

      expect(ack.banner, isNull);
      expect(player.plays, 0);
      ack.dispose();
    });

    test('a student\'s own broadcast packet (not a reply) and unrelated devices are ignored', () async {
      ack = await make();
      await ack.setListening(true);

      final mine = RotatingToken.blePacket(_secret, 10001, 59000000);
      scanner.hear([BlePacket.bytesToUuid(mine), '0000180f-0000-1000-8000-00805f9b34fb']);
      await _settle();

      expect(ack.banner, isNull);
      expect(player.plays, 0);
      ack.dispose();
    });

    test('the same reply burst heard many times ticks once', () async {
      ack = await make();
      await ack.setListening(true);
      final uuid = _reply(10001, _macFor(10001, 59000000));

      for (var i = 0; i < 6; i++) {
        scanner.hear([uuid]);
        await _settle(5);
      }

      expect(player.plays, 1);
      ack.dispose();
    });

    test('a NEW broadcast ticks again after the previous one was acknowledged', () async {
      ack = await make();
      final uuid = _reply(10001, _macFor(10001, 59000000));

      await ack.setListening(true);
      scanner.hear([uuid]);
      await _settle();
      expect(player.plays, 1);

      await ack.setListening(false);
      await ack.setListening(true); // "Broadcast again"
      scanner.hear([uuid]);
      await _settle();

      expect(player.plays, 2);
      ack.dispose();
    });

    test('banner hides by itself and can be dismissed', () async {
      ack = await make();
      await ack.setListening(true);
      scanner.hear([_reply(10001, _macFor(10001, 59000000))]);
      await _settle();
      expect(ack.banner, isNotNull);

      await _settle(300);
      expect(ack.banner, isNull);

      await ack.recorded();
      expect(ack.banner, AckKind.recorded);
      ack.dismiss();
      expect(ack.banner, isNull);
      ack.dispose();
    });

    test('no Bluetooth scan available: not listening, nothing breaks', () async {
      scanner.startWorks = false;
      ack = await make();
      await ack.setListening(true);

      expect(ack.isListening, isFalse);
      ack.dispose();
    });
  });

  testWidgets('end to end in the app: broadcasting, assistant replies, banner + tick appear', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    FlutterSecureStorage.setMockInitialValues({
      'token': 't',
      'user': jsonEncode({'id': 5, 'name': 'Omar Tester', 'student_number': 10001}),
      'secret': base64Encode(_secret),
    });
    final scanner = FakeReplyScanner();
    final player = FakePlayer();

    await tester.runAsync(() async {
      await tester.pumpWidget(StudentApp(
        locale: LocaleProvider('en'),
        api: ApiClient(client: MockClient((r) async => http.Response('{}', 200))),
        store: SecureStore(),
        advertiser: FakeAdvertiser(),
        replyScanner: scanner,
        tickPlayer: player,
        connectivity: Stream.value([]),
      ));
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      await tester.pump();

      expect(scanner.running, isTrue, reason: 'listening starts with the broadcast');

      final counter = RotatingToken.counter(DateTime.now().millisecondsSinceEpoch ~/ 1000);
      scanner.hear([_reply(10001, _macFor(10001, counter))]);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    });

    expect(find.text('Assistant scanned you successfully'), findsOneWidget);
    expect(player.plays, 1);

    await tester.pumpWidget(const SizedBox());
  });
}
