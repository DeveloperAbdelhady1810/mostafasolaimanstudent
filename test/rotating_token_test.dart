import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:student/services/rotating_token.dart';

void main() {
  // Same vector the server's App\Services\BleToken is tested against.
  final secret = Uint8List.fromList(List<int>.generate(32, (i) => i));

  test('MAC matches the server test vector', () {
    final mac = RotatingToken.mac(secret, 10001, 59000000);
    expect(mac.length, 9);
    expect(RotatingToken.hex(mac), 'b4a0fdce853f03dfc5');
  });

  test('QR payload format', () {
    expect(
      RotatingToken.qrPayload(secret, 10001, 59000000),
      'MSQ1:10001:59000000:b4a0fdce853f03dfc5',
    );
  });

  test('legacy payload is the static code the existing assistant app reads', () {
    expect(RotatingToken.legacyPayload(10001), 'LQ-010001');
    expect(RotatingToken.legacyPayload(7), 'LQ-000007');
  });

  test('counter changes every 30 seconds', () {
    expect(RotatingToken.counter(0), 0);
    expect(RotatingToken.counter(29), 0);
    expect(RotatingToken.counter(30), 1);
    expect(RotatingToken.counter(59000000 * 30 + 29), 59000000);
  });

  test('different counter or student gives a different MAC', () {
    final a = RotatingToken.hex(RotatingToken.mac(secret, 10001, 59000000));
    expect(RotatingToken.hex(RotatingToken.mac(secret, 10001, 59000001)), isNot(a));
    expect(RotatingToken.hex(RotatingToken.mac(secret, 10002, 59000000)), isNot(a));
  });

  test('Bluetooth packet layout: MS | v1 | student_no | MAC = 16 bytes', () {
    final p = RotatingToken.blePacket(secret, 10001, 59000000);
    expect(p.length, 16);
    expect(p.sublist(0, 3), [0x4D, 0x53, 0x01]);
    expect(p.sublist(3, 7), [0x00, 0x00, 0x27, 0x11]); // 10001
    expect(RotatingToken.hex(p.sublist(7)), 'b4a0fdce853f03dfc5');
  });
}
