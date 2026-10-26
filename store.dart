import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class AppStore extends ChangeNotifier {
  late SharedPreferences _prefs;
  List<AppUser> users = [];
  List<CsRecord> records = [];
  AppUser? current;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final u = _prefs.getString('users');
    if (u != null) {
      users = (jsonDecode(u) as List)
          .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final r = _prefs.getString('records');
    if (r != null) {
      records = (jsonDecode(r) as List)
          .map((e) => CsRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Default admin account (OSA)
    if (!users.any((x) => x.role == 'admin')) {
      users.add(AppUser(
        id: 'admin-1',
        name: 'OSA Admin',
        email: 'admin@school.edu',
        password: 'admin123',
        role: 'admin',
      ));
      await _save();
    }

    final cid = _prefs.getString('currentId');
    if (cid != null) {
      final matches = users.where((x) => x.id == cid);
      if (matches.isNotEmpty) current = matches.first;
    }
  }

  Future<void> _save() async {
    await _prefs.setString(
        'users', jsonEncode(users.map((e) => e.toJson()).toList()));
    await _prefs.setString(
        'records', jsonEncode(records.map((e) => e.toJson()).toList()));
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  // ---------- Auth ----------
  Future<String?> login(String email, String password) async {
    final matches = users.where((x) =>
        x.email.toLowerCase() == email.trim().toLowerCase() &&
        x.password == password);
    if (matches.isEmpty) return 'Mali ang email o password.';
    current = matches.first;
    await _prefs.setString('currentId', current!.id);
    notifyListeners();
    return null;
  }

  Future<String?> register({
    required String name,
    required String studentNo,
    required String email,
    required String password,
  }) async {
    if (users.any((x) => x.email.toLowerCase() == email.trim().toLowerCase())) {
      return 'May account na gamit ang email na ito.';
    }
    final user = AppUser(
      id: _newId(),
      name: name.trim(),
      email: email.trim(),
      password: password,
      role: 'student',
      studentNo: studentNo.trim(),
    );
    users.add(user);
    current = user;
    await _prefs.setString('currentId', user.id);
    await _save();
    notifyListeners();
    return null;
  }

  Future<void> logout() async {
    current = null;
    await _prefs.remove('currentId');
    notifyListeners();
  }

  // ---------- Queries ----------
  List<AppUser> get students => users.where((u) => !u.isAdmin).toList();

  AppUser? userById(String id) {
    final m = users.where((u) => u.id == id);
    return m.isEmpty ? null : m.first;
  }

  String studentName(String id) => userById(id)?.name ?? 'Unknown student';

  /// Admin sees everything, a student sees only their own tickets.
  List<CsRecord> get visibleRecords {
    final me = current;
    if (me == null) return [];
    final list = me.isAdmin
        ? [...records]
        : records.where((r) => r.studentId == me.id).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  // ---------- Records ----------
  Future<void> addRecord({
    required String studentId,
    required String violation,
    required double hoursRequired,
    DateTime? dutyDate,
    String dutyTime = '',
  }) async {
    final no = 'CS-${DateTime.now().year}-${(records.length + 1).toString().padLeft(4, '0')}';
    records.add(CsRecord(
      id: _newId(),
      ticketNo: no,
      studentId: studentId,
      violation: violation.trim(),
      hoursRequired: hoursRequired,
      dutyDate: dutyDate,
      dutyTime: dutyTime,
    ));
    await _save();
    notifyListeners();
  }

  Future<void> saveRecord(CsRecord r) async {
    r.refreshStatus();
    await _save();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    records.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> reschedule(CsRecord r, DateTime date, String time,
      String reason) async {
    r.dutyDate = date;
    r.dutyTime = time;
    r.note = reason;
    await _save();
    notifyListeners();
  }
}
