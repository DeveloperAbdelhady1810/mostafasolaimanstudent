import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Everything the app must still have with NO network: the session token, the
/// student's profile, the attendance secret and the cached lists. Kept in the
/// platform keystore (encrypted), never in plain preferences.
class SecureStore {
  SecureStore([FlutterSecureStorage? storage]) : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const kToken = 'token';
  static const kUser = 'user';
  static const kSecret = 'secret';
  static const kServerOffset = 'server_offset';
  static const kAttendance = 'cache_attendance';
  static const kNotifications = 'cache_notifications';
  static const kAttendanceAt = 'cache_attendance_at';

  Future<String?> read(String key) async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null; // a corrupted keystore entry must never block the app from opening
    }
  }

  Future<void> write(String key, String? value) async {
    try {
      if (value == null) {
        await _s.delete(key: key);
      } else {
        await _s.write(key: key, value: value);
      }
    } catch (_) {}
  }

  Future<dynamic> readJson(String key) async {
    final raw = await read(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeJson(String key, Object? value) => write(key, value == null ? null : jsonEncode(value));

  Future<void> clearAll() async {
    try {
      await _s.deleteAll();
    } catch (_) {}
  }
}
