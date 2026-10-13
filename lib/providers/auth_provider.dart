import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/secure_store.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

/// Owns the signed-in student and everything the offline code needs.
///
/// Signing in needs the internet. After that [restore] brings the session back
/// from the encrypted store with NO network call, so the student ID and the
/// code keep working in a basement classroom with no signal.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this.api, this.store) {
    api.onServerClock = _onServerClock;
    api.onUnauthorized = _onUnauthorized;
  }

  final ApiClient api;
  final SecureStore store;

  AuthStatus status = AuthStatus.loading;
  StudentUser? user;

  /// The per-student HMAC key; null while the rotating code is not enabled on the server.
  Uint8List? secret;

  /// server clock - phone clock, in seconds, learnt from every response.
  int serverOffset = 0;

  /// Set when the server rejected the stored token, so the login page can say why.
  bool sessionExpired = false;

  /// Fires once after a successful sign-in ([fresh] = true) or a restore from storage
  /// ([fresh] = false): load caches, sync, register for push.
  void Function(bool fresh)? onSignedIn;

  /// Fires just before the session is wiped (push token removal).
  Future<void> Function()? onBeforeSignOut;

  bool get isLoggedIn => status == AuthStatus.loggedIn;
  int? get studentNumber => user?.studentNumber;
  bool get hasSecureCode => secret != null && studentNumber != null;

  /// Current time as the server sees it, in unix seconds.
  int serverNow() => DateTime.now().millisecondsSinceEpoch ~/ 1000 + serverOffset;

  // ───────────────────────────── restore ─────────────────────────────────

  Future<void> restore() async {
    final token = await store.read(SecureStore.kToken);
    final userJson = await store.readJson(SecureStore.kUser);

    if (token == null || token.isEmpty || userJson is! Map) {
      status = AuthStatus.loggedOut;
      notifyListeners();
      return;
    }

    api.token = token;
    user = StudentUser.fromJson(Map<String, dynamic>.from(userJson));
    serverOffset = int.tryParse(await store.read(SecureStore.kServerOffset) ?? '') ?? 0;

    final b64 = await store.read(SecureStore.kSecret);
    if (b64 != null && b64.isNotEmpty) {
      try {
        secret = base64Decode(b64);
      } catch (_) {
        secret = null;
      }
    }

    status = AuthStatus.loggedIn;
    notifyListeners();
    onSignedIn?.call(false);
  }

  // ────────────────────────────── login ──────────────────────────────────

  /// Throws [ApiException] on failure (status 0 = no internet).
  Future<void> login(String login, String password) async {
    final res = await api.post('/auth/student-login', {'login': login.trim(), 'password': password});
    final map = Map<String, dynamic>.from(res as Map);

    final token = map['token'].toString();
    final u = StudentUser.fromJson(Map<String, dynamic>.from(map['user'] as Map));

    // A different student on the same phone must never inherit the previous secret or cache.
    await store.clearAll();

    api.token = token;
    user = u;
    secret = null;
    sessionExpired = false;

    await store.write(SecureStore.kToken, token);
    await store.writeJson(SecureStore.kUser, u.toJson());

    if (map['server_time'] is num) {
      _applyServerTime((map['server_time'] as num).toInt());
    }

    status = AuthStatus.loggedIn;
    notifyListeners();
    onSignedIn?.call(true);
  }

  // ───────────────────────────── the secret ──────────────────────────────

  /// Fetches (or re-fetches) the rotating-code secret. Silent on any failure:
  /// offline keeps the stored one, "not enabled yet" (403) falls back to the plain ID code.
  Future<void> refreshSecret() async {
    if (!isLoggedIn) return;
    try {
      final res = Map<String, dynamic>.from(await api.post('/student/ble/secret') as Map);
      final b64 = res['secret'].toString();
      final bytes = base64Decode(b64);
      if (bytes.length < 16) return;

      secret = bytes;
      await store.write(SecureStore.kSecret, b64);

      final no = (res['student_no'] as num?)?.toInt();
      if (no != null && no != user?.studentNumber && user != null) {
        user = StudentUser(
          id: user!.id,
          name: user!.name,
          email: user!.email,
          phone: user!.phone,
          studentNumber: no,
          avatar: user!.avatar,
        );
        await store.writeJson(SecureStore.kUser, user!.toJson());
      }
      if (res['server_time'] is num) _applyServerTime((res['server_time'] as num).toInt());
      notifyListeners();
    } on ApiException catch (e) {
      if (e.status == 403 && secret != null) {
        // The feature was switched off: go back to the plain ID code the old flow understands.
        secret = null;
        await store.write(SecureStore.kSecret, null);
        notifyListeners();
      }
    } catch (_) {}
  }

  // ───────────────────────────── logout ──────────────────────────────────

  bool _loggingOut = false;

  Future<void> logout({bool expired = false}) async {
    if (status == AuthStatus.loggedOut || _loggingOut) return;
    _loggingOut = true;
    try {
      // A rejected token is dead: don't make more calls with it (they would 401 again).
      if (expired) api.token = null;

      try {
        await onBeforeSignOut?.call();
      } catch (_) {}

      if (!expired && api.token != null) {
        try {
          await api.post('/auth/logout');
        } catch (_) {} // offline logout still clears this phone
      }

      api.token = null;
      user = null;
      secret = null;
      serverOffset = 0;
      sessionExpired = expired;
      await store.clearAll();
      status = AuthStatus.loggedOut;
      notifyListeners();
    } finally {
      _loggingOut = false;
    }
  }

  // ─────────────────────────── clock handling ────────────────────────────

  void _onUnauthorized() {
    if (status == AuthStatus.loggedIn) unawaited(logout(expired: true));
  }

  void _onServerClock(int offset) => _setOffset(offset);

  void _applyServerTime(int serverEpoch) =>
      _setOffset(serverEpoch - DateTime.now().millisecondsSinceEpoch ~/ 1000);

  void _setOffset(int offset) {
    // The HTTP Date header has 1-second resolution, so ignore +-1 s jitter.
    if ((offset - serverOffset).abs() < 2 && serverOffset != 0) return;
    if (offset == serverOffset) return;
    serverOffset = offset;
    unawaited(store.write(SecureStore.kServerOffset, offset.toString()));
    notifyListeners();
  }
}
