import 'package:flutter/foundation.dart';

import '../models.dart';
import '../services/api_client.dart';
import '../services/secure_store.dart';

/// A parent's children: the list (cached for offline), and each child's attendance and course progress.
class ParentProvider extends ChangeNotifier {
  ParentProvider(this.api, this.store);

  final ApiClient api;
  final SecureStore store;

  List<ChildSummary> children = [];
  bool loading = false;
  bool fromCache = false;
  bool failed = false;

  final Map<int, List<AttendanceRecord>> _attendance = {};
  final Map<int, ChildCourses> _courses = {};

  List<AttendanceRecord>? attendanceOf(int child) => _attendance[child];
  ChildCourses? coursesOf(int child) => _courses[child];

  Future<void> loadCache() async {
    final c = await store.readJson(SecureStore.kChildren);
    if (c is List) {
      children = c.whereType<Map>().map((e) => ChildSummary.fromJson(Map<String, dynamic>.from(e))).toList();
      fromCache = true;
      notifyListeners();
    }
  }

  Future<void> refreshChildren() async {
    loading = true;
    notifyListeners();
    try {
      final res = await api.get('/parent/children');
      final list = (res is Map ? res['children'] : null) as List? ?? const [];
      children = list.whereType<Map>().map((e) => ChildSummary.fromJson(Map<String, dynamic>.from(e))).toList();
      fromCache = false;
      failed = false;
      await store.writeJson(SecureStore.kChildren, children.map((e) => e.toJson()).toList());
    } on ApiException catch (e) {
      if (e.isOffline) failed = true;
    } catch (_) {
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Returns true when fresh data arrived (false = offline / error; any older data stays).
  Future<bool> refreshChild(int child) async {
    try {
      final res = await api.get('/parent/children/$child/attendance');
      final att = (res is Map ? res['records'] : null) as List? ?? const [];
      _attendance[child] = att.whereType<Map>().map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  void reset() {
    children = [];
    _attendance.clear();
    _courses.clear();
    fromCache = false;
    failed = false;
    notifyListeners();
  }
}
