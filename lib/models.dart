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
  });

  final int id;
  final String name;
  final String? email;
  final String? phone;
  final int? studentNumber;
  final String? avatar;

  factory StudentUser.fromJson(Map<String, dynamic> j) => StudentUser(
        id: (j['id'] as num?)?.toInt() ?? 0,
        name: (j['name'] ?? '').toString(),
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        studentNumber: (j['student_number'] as num?)?.toInt(),
        avatar: j['avatar']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'student_number': studentNumber,
        'avatar': avatar,
      };
}
