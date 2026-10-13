import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/ble_packet.dart';
import '../services/reply_scanner.dart';
import '../services/rotating_token.dart';
import '../services/tick_player.dart';
import 'auth_provider.dart';

enum AckKind {
  /// The assistant's phone heard this phone over Bluetooth (works offline).
  heard,

  /// The server recorded the attendance (push).
  recorded,
}

/// The confirmation the student sees: a tick sound and a banner "Assistant scanned you successfully".
/// It comes from two independent sources, either is enough:
///  - Bluetooth reply from the assistant's phone (works with no internet), verified against this
///    student's own rotating code so a stranger's phone cannot fake it;
///  - the push "attendance recorded" once the assistant confirmed on the server.
class AckProvider extends ChangeNotifier {
  AckProvider(
    this._auth, {
    ReplyScanner? scanner,
    TickPlayer? player,
    int Function()? clock,
    this.bannerDuration = const Duration(seconds: 4),
  })  : _scanner = scanner ?? PlusReplyScanner(),
        _player = player ?? AssetTickPlayer(),
        _clock = clock;

  final AuthProvider _auth;
  final ReplyScanner _scanner;
  final TickPlayer _player;
  final int Function()? _clock;
  final Duration bannerDuration;

  AckKind? banner;
  Timer? _hideTimer;
  StreamSubscription<List<String>>? _sub;
  bool _listening = false;
  bool _heardThisSession = false;

  bool get isListening => _listening;

  int _now() => _clock?.call() ?? _auth.serverNow();

  /// Called by the broadcaster: listen for replies exactly while this phone is broadcasting.
  Future<void> setListening(bool on) async {
    if (on == _listening) return;
    _listening = on;
    if (on) {
      _heardThisSession = false; // a new broadcast: the next reply ticks again
      _sub ??= _scanner.adverts.listen(_onAdvert);
      final ok = await _scanner.start();
      if (!ok) _listening = false;
    } else {
      await _scanner.stop();
      await _sub?.cancel();
      _sub = null;
    }
  }

  void _onAdvert(List<String> uuids) {
    for (final uuid in uuids) {
      final p = BlePacket.parse(uuid);
      if (p == null || !p.isReply) continue;
      if (_isMine(p)) {
        unawaited(_heard());
        return;
      }
    }
  }

  /// A reply counts only when it names this student AND echoes one of this phone's own recent codes.
  bool _isMine(ParsedBlePacket p) {
    final secret = _auth.secret;
    final no = _auth.studentNumber;
    if (secret == null || no == null || p.studentNo != no) return false;
    final counter = RotatingToken.counter(_now());
    for (var d = -2; d <= 2; d++) {
      if (RotatingToken.hex(RotatingToken.mac(secret, no, counter + d)) == p.macHex) return true;
    }
    return false;
  }

  Future<void> _heard() async {
    // The assistant repeats its reply a few times to make sure it is received: tick once per broadcast.
    if (_heardThisSession) return;
    _heardThisSession = true;
    await _show(AckKind.heard);
  }

  /// The push said the attendance was recorded.
  Future<void> recorded() => _show(AckKind.recorded);

  Future<void> _show(AckKind kind) async {
    banner = kind;
    notifyListeners();
    unawaited(_player.play());
    _hideTimer?.cancel();
    _hideTimer = Timer(bannerDuration, dismiss);
  }

  void dismiss() {
    _hideTimer?.cancel();
    if (banner != null) {
      banner = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _sub?.cancel();
    unawaited(_scanner.stop());
    super.dispose();
  }
}
