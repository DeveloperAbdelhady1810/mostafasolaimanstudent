import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/services/ble_packet.dart';
import 'package:student/services/rotating_token.dart';

void main() {
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => i));

  // Same vector as the server (BleToken) and the assistant app.
  const vectorUuid = '4d530100-0027-11b4-a0fd-ce853f03dfc5';

  test('student packet for the shared test vector becomes the expected UUID', () {
    final bytes = RotatingToken.blePacket(secret, 10001, 59000000);
    expect(BlePacket.bytesToUuid(bytes), vectorUuid);
  });

  test('RotatingToken.blePacket and BlePacket.student agree', () {
    final mac = RotatingToken.mac(secret, 10001, 59000000);
    expect(BlePacket.student(10001, mac), RotatingToken.blePacket(secret, 10001, 59000000));
  });

  test('parse recovers student number and MAC', () {
    final p = BlePacket.parse(vectorUuid)!;
    expect(p.isReply, isFalse);
    expect(p.studentNo, 10001);
    expect(p.macHex, 'b4a0fdce853f03dfc5');
  });

  test('parse accepts upper case and braces', () {
    final p = BlePacket.parse('{4D530100-0027-11B4-A0FD-CE853F03DFC5}')!;
    expect(p.studentNo, 10001);
    expect(p.macHex, 'b4a0fdce853f03dfc5');
  });

  test('reply packet uses the "MA" marker and the same layout', () {
    final mac = RotatingToken.mac(secret, 10001, 59000000);
    final uuid = BlePacket.bytesToUuid(BlePacket.reply(10001, mac));
    expect(uuid, '4d410100-0027-11b4-a0fd-ce853f03dfc5');
    final p = BlePacket.parse(uuid)!;
    expect(p.isReply, isTrue);
    expect(p.studentNo, 10001);
    expect(p.macHex, 'b4a0fdce853f03dfc5');
  });

  test('foreign Bluetooth UUIDs are ignored', () {
    expect(BlePacket.parse('0000180f-0000-1000-8000-00805f9b34fb'), isNull); // battery service
    expect(BlePacket.parse('180f'), isNull); // 16-bit form
    expect(BlePacket.parse(''), isNull);
    expect(BlePacket.parse('4d530200-0027-11b4-a0fd-ce853f03dfc5'), isNull); // unknown version
    expect(BlePacket.parse('4d530100-0000-00b4-a0fd-ce853f03dfc5'), isNull); // student number 0
    expect(BlePacket.parse('4d580100-0027-11b4-a0fd-ce853f03dfc5'), isNull); // unknown marker
  });

  test('round trip for large student numbers', () {
    final mac = List<int>.generate(9, (i) => 0xA0 + i);
    final uuid = BlePacket.bytesToUuid(BlePacket.student(4000000000, mac));
    final p = BlePacket.parse(uuid)!;
    expect(p.studentNo, 4000000000);
    expect(p.macHex, 'a0a1a2a3a4a5a6a7a8');
  });
}
