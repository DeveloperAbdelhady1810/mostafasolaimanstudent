import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Listens for the assistant's "I heard you" reply while this phone is broadcasting.
/// A seam so the logic can be tested without Bluetooth hardware.
abstract class ReplyScanner {
  /// Service UUIDs (128-bit text form) of every advertisement heard.
  Stream<List<String>> get adverts;
  Future<bool> start();
  Future<void> stop();
}

class PlusReplyScanner implements ReplyScanner {
  final StreamController<List<String>> _out = StreamController<List<String>>.broadcast();
  StreamSubscription<List<ScanResult>>? _sub;

  @override
  Stream<List<String>> get adverts => _out.stream;

  @override
  Future<bool> start() async {
    try {
      if (!await FlutterBluePlus.isSupported) return false;
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) return false;

      await _sub?.cancel();
      _sub = FlutterBluePlus.onScanResults.listen((results) {
        for (final r in results) {
          final uuids = r.advertisementData.serviceUuids.map((g) => g.str128).toList();
          if (uuids.isNotEmpty) _out.add(uuids);
        }
      });

      // Only ever runs during the 60 s broadcast window; every advertisement is reported (including
      // repeats) because the assistant's reply is a short burst.
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 90),
        continuousUpdates: true,
        oneByOne: true,
        androidLegacy: true,
        androidScanMode: AndroidScanMode.lowLatency,
      );
      return true;
    } catch (_) {
      return false; // no scan permission / no Bluetooth: the push still confirms attendance
    }
  }

  @override
  Future<void> stop() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    await _sub?.cancel();
    _sub = null;
  }
}
