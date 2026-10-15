import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/secure_store.dart';

/// Attendance history + notifications, cached in the encrypted store so both
/// screens still show the last known data with no network.
class DataProvider extends ChangeNotifier {
  DataProvider(this.api, this.store, {Stream<List<ConnectivityResult>>? connectivity}) {
    _listen(connectivity);
  }

  final ApiClient api;
  final SecureStore store;

  List<AttendanceRecord> attendance = [];
  DateTime? attendanceUpdatedAt;
  bool attendanceLoading = false;
  bool attendanceFromCache = false;

  List<AppNotification> notifications = [];
  bool notificationsLoading = false;

  /// A parent has no attendance of their own and their notifications live under /parent.
  bool parentMode = false;
  String get _notificationsPath => parentMode ? '/parent/notifications' : '/notifications';

  bool _noInterface = false;
  bool _lastCallFailed = false;

  /// Called each time the phone gets back online (re-fetch the secret, etc.).
  VoidCallback? onBackOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get offline => _noInterface || _lastCallFailed;
  int get unread => notifications.where((n) => !n.isRead).length;
  int get presentCount => attendance.where((a) => a.isPresent).length;
  AttendanceRecord? get lastAttended {
    for (final a in attendance) {
      if (a.isPresent) return a;
    }
    return null;
  }

  void _listen(Stream<List<ConnectivityResult>>? injected) {
    try {
      final stream = injected ?? Connectivity().onConnectivityChanged;
      _sub = stream.listen(_onConnectivity, onError: (_) {});
      if (injected == null) {
        Connectivity().checkConnectivity().then(_onConnectivity).catchError((_) {});
      }
    } catch (_) {
      // No connectivity plugin (tests / unsupported platform): rely on request results only.
    }
  }

  void _onConnectivity(List<ConnectivityResult> results) {
    final none = results.isEmpty || results.every((r) => r == ConnectivityResult.none);
    final cameBack = _noInterface && !none;
    _noInterface = none;
    if (!none) _lastCallFailed = false;
    notifyListeners();
    if (cameBack) onBackOnline?.call();
  }

  void _noteResult({required bool failed}) {
    if (_lastCallFailed != failed) {
      _lastCallFailed = failed;
      notifyListeners();
    }
  }

  // ───────────────────────────── cache ───────────────────────────────────

  Future<void> loadCache() async {
    final a = await store.readJson(SecureStore.kAttendance);
    if (a is List) {
      attendance = a.whereType<Map>().map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
      attendanceFromCache = true;
    }
    final at = await store.read(SecureStore.kAttendanceAt);
    attendanceUpdatedAt = at == null ? null : DateTime.tryParse(at);

    final n = await store.readJson(SecureStore.kNotifications);
    if (n is List) {
      notifications = n.whereType<Map>().map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    notifyListeners();
  }

  // ───────────────────────────── sync ────────────────────────────────────

  Future<void> syncAll() async {
    await Future.wait([if (!parentMode) refreshAttendance(), refreshNotifications()]);
  }

  Future<void> refreshAttendance() async {
    attendanceLoading = true;
    notifyListeners();
    try {
      final res = await api.get('/student/attendance');
      final list = (res is Map ? res['records'] : null) as List? ?? const [];
      attendance = list.whereType<Map>().map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
      attendanceFromCache = false;
      attendanceUpdatedAt = DateTime.now();
      _noteResult(failed: false);
      await store.writeJson(SecureStore.kAttendance, attendance.map((e) => e.toJson()).toList());
      await store.write(SecureStore.kAttendanceAt, attendanceUpdatedAt!.toIso8601String());
    } on ApiException catch (e) {
      if (e.isOffline) _noteResult(failed: true);
    } catch (_) {
    } finally {
      attendanceLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshNotifications() async {
    notificationsLoading = true;
    notifyListeners();
    try {
      final res = await api.get(_notificationsPath);
      final list = (res is List ? res : (res is Map ? res['data'] : null)) as List? ?? const [];
      notifications = list.whereType<Map>().map((e) => AppNotification.fromJson(Map<String, dynamic>.from(e))).toList();
      _noteResult(failed: false);
      await store.writeJson(SecureStore.kNotifications, notifications.map((e) => e.toJson()).toList());
    } on ApiException catch (e) {
      if (e.isOffline) _noteResult(failed: true);
    } catch (_) {
    } finally {
      notificationsLoading = false;
      notifyListeners();
    }
  }

  Future<void> markRead(AppNotification n) async {
    if (n.isRead) return;
    n.readAt = DateTime.now().toIso8601String();
    notifyListeners();
    unawaited(store.writeJson(SecureStore.kNotifications, notifications.map((e) => e.toJson()).toList()));
    try {
      await api.post('$_notificationsPath/${n.id}/read');
    } catch (_) {} // the next successful refresh reconciles
  }

  Future<void> markAllRead() async {
    final now = DateTime.now().toIso8601String();
    for (final n in notifications) {
      n.readAt ??= now;
    }
    notifyListeners();
    unawaited(store.writeJson(SecureStore.kNotifications, notifications.map((e) => e.toJson()).toList()));
    try {
      await api.post('$_notificationsPath/mark-all-read');
    } catch (_) {}
  }

  void reset() {
    attendance = [];
    notifications = [];
    attendanceUpdatedAt = null;
    attendanceFromCache = false;
    _lastCallFailed = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
