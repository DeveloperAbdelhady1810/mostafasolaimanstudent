import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../services/rotating_token.dart';
import 'auth_provider.dart';

/// Ticks once a second and exposes the text to put in the QR, computed entirely
/// on the phone (no network): rotating `MSQ1:` code when the secret is stored,
/// otherwise the plain `LQ-` ID code the existing assistant app already reads.
class CodeProvider extends ChangeNotifier {
  CodeProvider(this._auth, {int Function()? clock}) : _clock = clock {
    _auth.addListener(_recompute);
    _recompute();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _recompute());
  }

  final AuthProvider _auth;
  final int Function()? _clock;
  Timer? _timer;

  String? payload;
  int secondsLeft = codeWindowSeconds;
  bool get isRotating => _auth.hasSecureCode;

  /// 0..1, how much of the current 30 s window is left (drives the ring).
  double get progress => secondsLeft / codeWindowSeconds;

  void _recompute() {
    final no = _auth.studentNumber;
    String? next;
    var left = codeWindowSeconds;

    if (no != null) {
      final now = _clock?.call() ?? _auth.serverNow();
      final counter = RotatingToken.counter(now);
      left = codeWindowSeconds - (now % codeWindowSeconds);
      next = _auth.hasSecureCode
          ? RotatingToken.qrPayload(_auth.secret!, no, counter)
          : RotatingToken.legacyPayload(no);
    }

    if (next != payload || left != secondsLeft) {
      payload = next;
      secondsLeft = left;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth.removeListener(_recompute);
    super.dispose();
  }
}
