import 'package:flutter/services.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';

enum AdvertiseResult { ok, permissionDenied, bluetoothOff, unsupported, error }

/// What the broadcaster needs from the phone's Bluetooth radio. A thin seam so the
/// broadcast logic can be tested without hardware.
abstract class BleAdvertiser {
  Future<bool> get isSupported;
  Future<bool> hasPermission();
  Future<bool> requestPermission();

  /// Asks the user to turn Bluetooth on (Android shows a system prompt).
  Future<bool> enableBluetooth();

  /// Starts advertising [serviceUuid] (non-connectable). Replaces anything already advertising.
  Future<AdvertiseResult> start(String serviceUuid);
  Future<void> stop();
  Future<void> openAppSettings();
}

class PluginAdvertiser implements BleAdvertiser {
  final FlutterBlePeripheral _p = FlutterBlePeripheral();

  @override
  Future<bool> get isSupported async {
    try {
      return await _p.isSupported;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _p.hasPermission() == PeripheralBluetoothState.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> requestPermission() async {
    try {
      return await _p.requestPermission() == PeripheralBluetoothState.granted;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> enableBluetooth() async {
    try {
      return await _p.enableBluetooth();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AdvertiseResult> start(String serviceUuid) async {
    try {
      final state = await _p.start(
        advertiseData: AdvertiseDataCore(serviceUuid: serviceUuid),
        androidSettings: const AndroidAdvertiseSettings(
          advertiseSettings: AdvertiseSettings(
            connectable: false,
            timeout: 0,
            advertiseMode: AdvertiseMode.advertiseModeLowLatency,
            txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
          ),
        ),
      );
      switch (state) {
        case PeripheralBluetoothState.ready:
        case PeripheralBluetoothState.granted:
          return AdvertiseResult.ok;
        case PeripheralBluetoothState.turnedOff:
          return AdvertiseResult.bluetoothOff;
        case PeripheralBluetoothState.denied:
        case PeripheralBluetoothState.permanentlyDenied:
        case PeripheralBluetoothState.restricted:
          return AdvertiseResult.permissionDenied;
        case PeripheralBluetoothState.unsupported:
          return AdvertiseResult.unsupported;
        default:
          return AdvertiseResult.error;
      }
    } on PlatformException catch (e) {
      final text = '${e.code} ${e.message}'.toLowerCase();
      if (text.contains('permission')) return AdvertiseResult.permissionDenied;
      if (text.contains('off') || text.contains('disabled')) return AdvertiseResult.bluetoothOff;
      if (text.contains('support')) return AdvertiseResult.unsupported;
      return AdvertiseResult.error;
    } catch (_) {
      return AdvertiseResult.error;
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _p.stop();
    } catch (_) {}
  }

  @override
  Future<void> openAppSettings() async {
    try {
      await _p.openAppSettings();
    } catch (_) {}
  }
}
