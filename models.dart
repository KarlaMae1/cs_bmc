import 'dart:math';

class AppUser {
  final String id;
  final String name;
  final String email;
  final String password;
  final String role; // 'admin' or 'student'
  final String studentNo;

  AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    this.studentNo = '',
  });

  bool get isAdmin => role == 'admin';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'password': password,
        'role': role,
        'studentNo': studentNo,
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'],
        name: j['name'],
        email: j['email'],
        password: j['password'],
        role: j['role'],
        studentNo: j['studentNo'] ?? '',
      );
}

class CsRecord {
  final String id;
  final String ticketNo;
  String studentId;
  String violation;
  double hoursRequired;
  double hoursRendered;
  String status; // Pending, Ongoing, Completed
  DateTime? dutyDate;
  String dutyTime;
  String note; // reschedule reason / remarks
  final DateTime createdAt;

  CsRecord({
    required this.id,
    required this.ticketNo,
    required this.studentId,
    required this.violation,
    required this.hoursRequired,
    this.hoursRendered = 0,
    this.status = 'Pending',
    this.dutyDate,
    this.dutyTime = '',
    this.note = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  double get remaining => max(0, hoursRequired - hoursRendered);
  double get progress =>
      hoursRequired <= 0 ? 0 : (hoursRendered / hoursRequired).clamp(0.0, 1.0);

  void refreshStatus() {
    if (hoursRendered >= hoursRequired) {
      status = 'Completed';
    } else if (hoursRendered > 0) {
      status = 'Ongoing';
    } else {
      status = 'Pending';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ticketNo': ticketNo,
        'studentId': studentId,
        'violation': violation,
        'hoursRequired': hoursRequired,
        'hoursRendered': hoursRendered,
        'status': status,
        'dutyDate': dutyDate?.toIso8601String(),
        'dutyTime': dutyTime,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory CsRecord.fromJson(Map<String, dynamic> j) => CsRecord(
        id: j['id'],
        ticketNo: j['ticketNo'],
        studentId: j['studentId'],
        violation: j['violation'],
        hoursRequired: (j['hoursRequired'] as num).toDouble(),
        hoursRendered: (j['hoursRendered'] as num).toDouble(),
        status: j['status'],
        dutyDate:
            j['dutyDate'] == null ? null : DateTime.parse(j['dutyDate']),
        dutyTime: j['dutyTime'] ?? '',
        note: j['note'] ?? '',
        createdAt: DateTime.parse(j['createdAt']),
      );
}
