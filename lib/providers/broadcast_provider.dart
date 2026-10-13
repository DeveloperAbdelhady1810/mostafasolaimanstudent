import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/ble_advertiser.dart';
import '../services/ble_packet.dart';
import '../services/rotating_token.dart';
import 'auth_provider.dart';

enum BroadcastStatus { idle, starting, active, needsPermission, bluetoothOff, unsupported, error }

/// Broadcasts the student's rotating code over Bluetooth so the assistant's radar can detect the
/// whole class at once. Works with no internet (everything is computed from the stored secret).
///
/// Rules (from the agreed design): broadcast for 60 s whenever the app is open, then stop to save
/// battery ("Broadcast again" restarts it); the packet is rebuilt every 30 s when the code rotates;
/// nothing is broadcast while the app is in the background or when the secure code is not available.
class BroadcastProvider extends ChangeNotifier {
  BroadcastProvider(
    this._auth, {
    BleAdvertiser? advertiser,
    SharedPreferences? prefs,
    int Function()? clock,
    this.sessionSeconds = 60,
    bool autoRun = true,
  })  : _adv = advertiser ?? PluginAdvertiser(),
        _prefs = prefs,
        _clock = clock {
    if (autoRun) _auth.addListener(_onAuthChanged);
    _autoRun = autoRun;
  }

  static const _askedKey = 'ble_permission_asked';

  final AuthProvider _auth;
  final BleAdvertiser _adv;
  final SharedPreferences? _prefs;
  final int Function()? _clock;
  final int sessionSeconds;
  late final bool _autoRun;

  BroadcastStatus status = BroadcastStatus.idle;
  int secondsLeft = 0;

  /// A broadcast has already run in this app session (the button then reads "Broadcast again").
  bool hasBroadcastBefore = false;

  /// While true, no automatic start happens (used so the Bluetooth permission prompt does not stack on
  /// top of the notification prompt right after the first login, which makes Android drop one of them).
  bool holdAutoStart = false;

  Timer? _timer;
  int? _advertisedCounter;
  bool _busy = false;
  bool _foreground = true;
  bool _autoStartDone = false;

  /// The secure code (and so the broadcast) exists only once the server has switched the feature on.
  bool get available => _auth.hasSecureCode;
  bool get isActive => status == BroadcastStatus.active;
  double get progress => sessionSeconds == 0 ? 0 : secondsLeft / sessionSeconds;

  int _now() => _clock?.call() ?? _auth.serverNow();

  // ───────────────────────────── lifecycle ────────────────────────────────

  /// App came to the foreground: broadcast again (once permission was already given).
  void onForeground() {
    _foreground = true;
    _autoStartDone = false;
    _maybeAutoStart();
  }

  /// App left the foreground: iPhones stop anyway, and Android should not drain the battery silently.
  void onBackground() {
    _foreground = false;
    if (!_busy && isActive) unawaited(stop());
  }

  void _onAuthChanged() {
    if (!_auth.hasSecureCode) {
      _autoStartDone = false;
      if (status != BroadcastStatus.idle) unawaited(stop());
      return;
    }
    _maybeAutoStart();
  }

  void _maybeAutoStart() {
    if (!_autoRun || !_foreground || !available || _autoStartDone || _busy || holdAutoStart) return;
    if (status == BroadcastStatus.active) return;
    _autoStartDone = true;
    unawaited(start());
  }

  // ───────────────────────────── start / stop ─────────────────────────────

  /// [userInitiated] = the student tapped the button: may ask for permission / to turn Bluetooth on.
  Future<void> start({bool userInitiated = false}) async {
    if (!available || _busy) return;
    _busy = true;
    _timer?.cancel();
    status = BroadcastStatus.starting;
    notifyListeners();

    try {
      if (!await _adv.isSupported) {
        status = BroadcastStatus.unsupported;
        return;
      }

      if (!await _adv.hasPermission()) {
        // On a quiet auto-start we ask only the very first time; afterwards the student presses the button.
        if (userInitiated || !await _askedBefore()) {
          await _markAsked();
          if (!await _adv.requestPermission()) {
            status = BroadcastStatus.needsPermission;
            return;
          }
        } else {
          status = BroadcastStatus.needsPermission;
          return;
        }
      }

      var result = await _advertiseCurrent();
      if (result == AdvertiseResult.bluetoothOff && userInitiated && await _adv.enableBluetooth()) {
        result = await _advertiseCurrent();
      }

      if (result != AdvertiseResult.ok) {
        status = _statusFor(result);
        return;
      }

      secondsLeft = sessionSeconds;
      hasBroadcastBefore = true;
      status = BroadcastStatus.active;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => unawaited(_tick()));
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _advertisedCounter = null;
    secondsLeft = 0;
    status = BroadcastStatus.idle;
    notifyListeners();
    await _adv.stop();
  }

  Future<void> openSettings() => _adv.openAppSettings();

  Future<void> _tick() async {
    if (status != BroadcastStatus.active || _busy) return;
    secondsLeft--;
    if (secondsLeft <= 0) {
      await stop();
      return;
    }
    // The code rotates every 30 s: put the new packet on air.
    if (RotatingToken.counter(_now()) != _advertisedCounter) {
      _busy = true;
      final result = await _advertiseCurrent();
      _busy = false;
      if (result != AdvertiseResult.ok) {
        _timer?.cancel();
        status = _statusFor(result);
        secondsLeft = 0;
      }
    }
    notifyListeners();
  }

  /// Builds the packet for the current 30 s window and puts it on air (replacing the previous one).
  Future<AdvertiseResult> _advertiseCurrent() async {
    final secret = _auth.secret;
    final no = _auth.studentNumber;
    if (secret == null || no == null) return AdvertiseResult.error;

    final counter = RotatingToken.counter(_now());
    final uuid = BlePacket.bytesToUuid(RotatingToken.blePacket(secret, no, counter));
    await _adv.stop();
    final result = await _adv.start(uuid);
    if (result == AdvertiseResult.ok) _advertisedCounter = counter;
    return result;
  }

  BroadcastStatus _statusFor(AdvertiseResult r) {
    switch (r) {
      case AdvertiseResult.permissionDenied:
        return BroadcastStatus.needsPermission;
      case AdvertiseResult.bluetoothOff:
        return BroadcastStatus.bluetoothOff;
      case AdvertiseResult.unsupported:
        return BroadcastStatus.unsupported;
      default:
        return BroadcastStatus.error;
    }
  }

  Future<bool> _askedBefore() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      return prefs.getBool(_askedKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> _markAsked() async {
    try {
      final prefs = _prefs ?? await SharedPreferences.getInstance();
      await prefs.setBool(_askedKey, true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_autoRun) _auth.removeListener(_onAuthChanged);
    unawaited(_adv.stop());
    super.dispose();
  }
}
