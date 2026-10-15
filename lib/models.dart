import 'utils.dart';

class AttendanceRecord {
  AttendanceRecord({
    required this.id,
    required this.course,
    this.center,
    this.date,
    required this.status,
    this.scannedAt,
  });

  final int id;
  final String course;
  final String? center;
  final String? date; // yyyy-MM-dd (time part ignored)
  final String status; // present | absent
  final String? scannedAt;

  bool get isPresent => status == 'present';

  DateTime? get day => date == null ? null : DateTime.tryParse(date!.length >= 10 ? date!.substring(0, 10) : date!);

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        id: (j['id'] as num?)?.toInt() ?? 0,
        course: (j['course'] ?? '').toString(),
        center: j['center']?.toString(),
        date: j['date']?.toString(),
        status: (j['status'] ?? 'absent').toString(),
        scannedAt: j['scanned_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'course': course,
        'center': center,
        'date': date,
        'status': status,
        'scanned_at': scannedAt,
      };
}

class AppNotification {
  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.readAt,
    this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  String? readAt;
  final String? createdAt;

  bool get isRead => readAt != null && readAt!.isNotEmpty;

  DateTime? get created => parseServerTime(createdAt);

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: (j['id'] as num?)?.toInt() ?? 0,
        type: (j['type'] ?? '').toString(),
        title: (j['title'] ?? '').toString(),
        body: (j['body'] ?? '').toString(),
        readAt: j['read_at']?.toString(),
        createdAt: j['created_at']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'body': body,
        'read_at': readAt,
        'created_at': createdAt,
      };
}

class StudentUser {
  StudentUser({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.studentNumber,
    this.avatar,
    this.role = 'student',
    this.mustChangePassword = false,
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final int? studentNumber;
  final String? avatar;

  /// 'student' or 'parent' - a parent signs in to the same app and sees their children.
  final String role;

  /// Parents whose first password was set by the school must choose their own before using the app.
  final bool mustChangePassword;

  bool get isParent => role == 'parent';

  StudentUser copyWith({int? studentNumber, bool? mustChangePassword}) => StudentUser(
        id: id,
        name: name,
        email: email,
        phone: phone,
        studentNumber: studentNumber ?? this.studentNumber,
        avatar: avatar,
        role: role,
        mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      );

  factory StudentUser.fromJson(Map<String, dynamic> j) => StudentUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        studentNumber: (j['student_number'] as num?)?.toInt(),
        avatar: j['avatar']?.toString(),
        role: (j['role'] ?? 'student').toString() == 'parent' ? 'parent' : 'student',
        mustChangePassword: j['must_change_password'] == true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'student_number': studentNumber,
        'avatar': avatar,
        'role': role,
        'must_change_password': mustChangePassword,
      };
}

/// One child of a parent, as listed on the parent's home screen.
class ChildSummary {
  ChildSummary({
    required this.id,
    required this.name,
    this.studentNumber,
    this.grade = '',
    this.studyMode,
    this.center,
    this.present = 0,
    this.absent = 0,
    this.courses = 0,
    this.progress = 0,
    this.lastAttended,
  });

  final int id;
  final String name;
  final int? studentNumber;
  final String grade;
  final String? studyMode;
  final String? center;
  final int present;
  final int absent;
  final int courses;
  final int progress; // 0-100, lectures completed
  final String? lastAttended; // yyyy-MM-dd

  int get total => present + absent;

  factory ChildSummary.fromJson(Map<String, dynamic> j) => ChildSummary(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        studentNumber: (j['student_number'] as num?)?.toInt(),
        grade: (j['grade'] ?? '').toString(),
        studyMode: j['study_mode']?.toString(),
        center: j['center']?.toString(),
        present: (j['present'] as num?)?.toInt() ?? 0,
        absent: (j['absent'] as num?)?.toInt() ?? 0,
        courses: (j['courses'] as num?)?.toInt() ?? 0,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
        lastAttended: j['last_attended']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'student_number': studentNumber,
        'grade': grade,
        'study_mode': studyMode,
        'center': center,
        'present': present,
        'absent': absent,
        'courses': courses,
        'progress': progress,
        'last_attended': lastAttended,
      };
}

class ChildCourse {
  ChildCourse({required this.id, required this.title, this.subject, this.done = 0, this.total = 0, this.progress = 0});

  final int id;
  final String title;
  final String? subject;
  final int done;
  final int total;
  final int progress;

  factory ChildCourse.fromJson(Map<String, dynamic> j) => ChildCourse(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: (j['title'] ?? '').toString(),
        subject: j['subject']?.toString(),
        done: (j['lectures_done'] as num?)?.toInt() ?? 0,
        total: (j['lectures_total'] as num?)?.toInt() ?? 0,
        progress: (j['progress'] as num?)?.toInt() ?? 0,
      );
}

class ChildCourses {
  ChildCourses({this.courses = const [], this.quizzesTaken = 0, this.quizzesPassed = 0});

  final List<ChildCourse> courses;
  final int quizzesTaken;
  final int quizzesPassed;

  factory ChildCourses.fromJson(Map<String, dynamic> j) => ChildCourses(
        courses: (j['courses'] as List? ?? const []).whereType<Map>().map((e) => ChildCourse.fromJson(Map<String, dynamic>.from(e))).toList(),
        quizzesTaken: (j['quizzes_taken'] as num?)?.toInt() ?? 0,
        quizzesPassed: (j['quizzes_passed'] as num?)?.toInt() ?? 0,
      );
}
