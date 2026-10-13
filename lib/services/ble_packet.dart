import 'dart:typed_data';

/// The Bluetooth packet is one 128-bit service UUID (the only free-form data an iPhone is allowed to
/// advertise). Its 16 bytes are:
///
///   `0x4D 0x53` ("MS")  | version 0x01 | student_no (4 bytes, big-endian) | MAC (9 bytes)
///
/// and the assistant's reply uses the marker `0x4D 0x41` ("MA") with the same layout.
/// Must stay identical to the assistant app's copy (`lib/services/ble_packet.dart`); the test vector is in
/// `test/ble_packet_test.dart` of both apps.
class BlePacket {
  static const int length = 16;
  static const int version = 1;
  static const int markerM = 0x4D;
  static const int studentMarker = 0x53; // 'S'  -> student's own broadcast
  static const int assistantMarker = 0x41; // 'A' -> assistant's reply

  /// 16 packet bytes -> `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`.
  static String bytesToUuid(List<int> bytes) {
    assert(bytes.length == length);
    final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
  }

  /// Any textual UUID form (8-4-4-4-12, braces, upper case) -> 16 bytes, or null if it is not a full 128-bit UUID.
  static Uint8List? uuidToBytes(String uuid) {
    final hex = uuid.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    if (hex.length != 32) return null;
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  static Uint8List build(int marker2, int studentNo, List<int> mac) {
    final b = BytesBuilder()
      ..add([markerM, marker2, version])
      ..add((ByteData(4)..setUint32(0, studentNo, Endian.big)).buffer.asUint8List())
      ..add(mac);
    return b.toBytes();
  }

  /// Student broadcast packet for the given MAC.
  static Uint8List student(int studentNo, List<int> mac) => build(studentMarker, studentNo, mac);

  /// Assistant reply packet echoing the MAC it heard.
  static Uint8List reply(int studentNo, List<int> mac) => build(assistantMarker, studentNo, mac);

  /// Parses a UUID that carries one of our packets; null for any other Bluetooth device's UUID.
  static ParsedBlePacket? parse(String uuid) {
    final bytes = uuidToBytes(uuid);
    if (bytes == null || bytes[0] != markerM || bytes[2] != version) return null;
    final kind = bytes[1];
    if (kind != studentMarker && kind != assistantMarker) return null;
    final studentNo = ByteData.sublistView(bytes, 3, 7).getUint32(0, Endian.big);
    if (studentNo == 0) return null;
    final mac = bytes.sublist(7, 16);
    return ParsedBlePacket(
      isReply: kind == assistantMarker,
      studentNo: studentNo,
      macHex: mac.map((b) => b.toRadixString(16).padLeft(2, '0')).join(),
    );
  }
}

class ParsedBlePacket {
  const ParsedBlePacket({required this.isReply, required this.studentNo, required this.macHex});

  /// true = assistant's "I heard you" reply, false = a student's own broadcast.
  final bool isReply;
  final int studentNo;
  final String macHex;
}
