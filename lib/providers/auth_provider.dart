import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/secure_store.dart';
import '../services/social_auth_service.dart';
import '../social_models.dart';

enum AuthStatus { loading, loggedOut, loggedIn }

/// Owns the signed-in student and everything the offline code needs.
///
/// Signing in needs the internet. After that [restore] brings the session back
/// from the encrypted store with NO network call, so the student ID and the
/// code keep working in a basement classroom with no signal.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this.api, this.store, {SocialAuth? social}) : social = social ?? PlatformSocialAuth() {
    api.onServerClock = _onServerClock;
    api.onUnauthorized = _onUnauthorized;
  }

  final ApiClient api;
  final SecureStore store;

  /// The phone's native Google / Apple sign-in.
  final SocialAuth social;

  SocialConfig? _socialConfig;

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
    await _finishLogin(Map<String, dynamic>.from(res as Map));
  }

  /// Stores a session the server just issued ({token, user, server_time}) and opens the app.
  Future<void> _finishLogin(Map<String, dynamic> map) async {
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

  // ───────────────────────── Google / Apple sign-in ──────────────────────────

  /// What the server allows (which buttons to show, and the Google client id). Public; cached after the first success.
  Future<SocialConfig> socialConfig() async {
    final cached = _socialConfig;
    if (cached != null) return cached;
    final res = await api.get('/auth/social/config');
    return _socialConfig = SocialConfig.fromJson(Map<String, dynamic>.from(res as Map));
  }

  bool get appleAvailable => social.appleAvailable;

  /// Opens the provider's own sign-in, then asks the server to verify it.
  /// Returns null when the student is signed in, or a [SocialPending] when the email has no student
  /// account yet and the profile form must be filled in ([completeProfile]).
  ///
  /// Throws [SocialAuthException] (cancelled / unavailable / failed) or [ApiException].
  Future<SocialPending?> socialLogin(SocialProvider provider) async {
    final SocialIdentity identity;
    if (provider == SocialProvider.google) {
      final config = await socialConfig();
      final clientId = config.googleServerClientId;
      if (!config.googleEnabled || clientId == null || clientId.isEmpty) {
        throw const SocialAuthException(SocialFailure.unavailable, 'google is not set up on the server');
      }
      identity = await social.google(serverClientId: clientId);
    } else {
      identity = await social.apple();
    }

    final res = provider == SocialProvider.google
        ? await api.post('/auth/social/google', {'id_token': identity.token})
        : await api.post('/auth/social/apple', {
            'identity_token': identity.token,
            'nonce': identity.nonce,
            if (identity.name != null) 'name': identity.name,
          });
    final map = Map<String, dynamic>.from(res as Map);

    if (map['needs_profile'] == true) {
      return SocialPending(
        ticket: map['ticket'].toString(),
        email: (map['email'] ?? '').toString(),
        name: (map['name'] ?? '').toString(),
      );
    }
    await _finishLogin(map);
    return null;
  }

  Future<RegistrationOptions> registrationOptions() async {
    final res = await api.get('/auth/social/options');
    return RegistrationOptions.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Creates the student account (the same fields the website asks) and signs in.
  /// A 422 [ApiException] carries [ApiException.fieldErrors]; a 410 means the sign-in expired.
  Future<void> completeProfile(String ticket, Map<String, dynamic> fields) async {
    final res = await api.post('/auth/social/complete', {'ticket': ticket, ...fields});
    await _finishLogin(Map<String, dynamic>.from(res as Map));
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
