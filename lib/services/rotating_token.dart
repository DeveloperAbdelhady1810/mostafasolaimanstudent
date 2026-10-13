import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../config.dart';

/// The rotating proof shown as a QR (and later broadcast over Bluetooth).
///
///   counter = floor((unix_time + server_offset) / 30)
///   MAC     = first 9 bytes of HMAC-SHA256(secret, "MS1" | student_no (uint32 BE) | counter (uint64 BE))
///
/// Byte-for-byte the same as the server's App\Services\BleToken (test vector in
/// test/rotating_token_test.dart).
class RotatingToken {
  static const int macBytes = 9;

  static int counter(int unixSeconds) => unixSeconds ~/ codeWindowSeconds;

  static Uint8List mac(Uint8List secret, int studentNo, int counter) {
    final msg = BytesBuilder()
      ..add(ascii.encode('MS1'))
      ..add((ByteData(4)..setUint32(0, studentNo, Endian.big)).buffer.asUint8List())
      ..add((ByteData(8)..setUint64(0, counter, Endian.big)).buffer.asUint8List());
    final digest = Hmac(sha256, secret).convert(msg.toBytes()).bytes;
    return Uint8List.fromList(digest.sublist(0, macBytes));
  }

  static String hex(List<int> bytes) => bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

  /// Rotating QR text: `MSQ1:{student_no}:{counter}:{mac as 18 hex}`
  static String qrPayload(Uint8List secret, int studentNo, int counter) =>
      'MSQ1:$studentNo:$counter:${hex(mac(secret, studentNo, counter))}';

  /// Static code the existing assistant app already scans (used until the secret is available).
  static String legacyPayload(int studentNo) => '$legacyQrPrefix${studentNo.toString().padLeft(6, '0')}';

  /// Bluetooth packet (service UUID bytes): "MS" | version 1 | student_no (4) | MAC (9) = 16 bytes.
  static Uint8List blePacket(Uint8List secret, int studentNo, int counter) {
    final b = BytesBuilder()
      ..add([0x4D, 0x53, 0x01])
      ..add((ByteData(4)..setUint32(0, studentNo, Endian.big)).buffer.asUint8List())
      ..add(mac(secret, studentNo, counter));
    return b.toBytes();
  }
}
