import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

const String attendanceChannelId = 'attendance';

/// Must be a top-level function. Messages that carry a `notification` block are
/// shown by the system itself; this only exists so data-only pushes keep working later.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging: registers this phone's token with the server so
/// "your attendance was confirmed" and teacher messages arrive as push.
class PushService extends ChangeNotifier {
  PushService(this._api);

  final ApiClient _api;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();

  /// False when Firebase could not start (unsupported device, missing Play services...).
  bool available = false;

  /// Notification permission granted.
  bool permitted = false;

  String? _token;
  bool _registered = false;
  final List<StreamSubscription> _subs = [];

  /// A push arrived while the app is open (refresh the lists).
  VoidCallback? onMessage;

  /// The student tapped a notification (jump to the notifications tab).
  VoidCallback? onOpen;

  Future<void> init({required bool firebaseReady}) async {
    if (!firebaseReady) return;
    try {
      available = true;
      final fm = FirebaseMessaging.instance;

      await _local.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_notify'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
        onDidReceiveNotificationResponse: (_) => onOpen?.call(),
      );

      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            attendanceChannelId,
            'Attendance & messages',
            description: 'Attendance confirmations and messages from your teacher',
            importance: Importance.high,
          ));

      await fm.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

      _subs.add(FirebaseMessaging.onMessage.listen(_onForeground));
      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen((_) => onOpen?.call()));
      _subs.add(fm.onTokenRefresh.listen((t) {
        _token = t;
        _registered = false;
        unawaited(register());
      }));

      final initial = await fm.getInitialMessage();
      if (initial != null) onOpen?.call();

      final settings = await fm.getNotificationSettings();
      permitted = _isAllowed(settings.authorizationStatus);
    } catch (e) {
      available = false;
      debugPrint('Push init failed: $e');
    }
    notifyListeners();
  }

  bool _isAllowed(AuthorizationStatus s) =>
      s == AuthorizationStatus.authorized || s == AuthorizationStatus.provisional;

  /// Ask for permission (if needed) and register the token. Safe to call repeatedly.
  Future<bool> enable() async {
    if (!available) return false;
    try {
      final settings = await FirebaseMessaging.instance.requestPermission();
      permitted = _isAllowed(settings.authorizationStatus);
    } catch (_) {
      permitted = false;
    }
    notifyListeners();
    if (permitted) await register();
    return permitted;
  }

  /// Sends the FCM token to the server for the signed-in student. Needs internet;
  /// failures are retried the next time the phone is online.
  Future<void> register() async {
    if (!available || !permitted || _registered || _api.token == null) return;
    try {
      _token ??= await FirebaseMessaging.instance.getToken();
      if (_token == null) return;
      await _api.post('/device-token', {
        'fcm_token': _token,
        'platform': Platform.isIOS ? 'ios' : 'android',
        'app': 'student',
      });
      _registered = true;
    } catch (_) {}
  }

  /// Removes this phone from the student's push list (call before logging out).
  Future<void> unregister() async {
    if (!available) return;
    try {
      final t = _token ?? await FirebaseMessaging.instance.getToken();
      if (t != null && _api.token != null) {
        await _api.delete('/device-token', {'fcm_token': t});
      }
    } catch (_) {}
    _registered = false;
  }

  Future<void> _onForeground(RemoteMessage m) async {
    onMessage?.call();
    // iOS shows its own banner while the app is open; Android needs one drawn here.
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final n = m.notification;
    if (n == null) return;
    await _local.show(
      m.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          attendanceChannelId,
          'Attendance & messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_notify',
          color: Color(0xFF059669),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
