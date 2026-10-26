import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

class AppStore extends ChangeNotifier {
  final ApiClient _api = ApiClient();
  SharedPreferences? _prefs;
  List<AppUser> users = [];
  List<CsRecord> records = [];
  AppUser? current;
  String? connectionError;

  Uri? profilePhotoUri(String? path) => _api.mediaUri(path);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _api.token = _prefs!.getString('apiToken');
    if (_api.token == null) return;

    try {
      await _loadData();
      connectionError = null;
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearToken();
      } else {
        connectionError = error.message;
      }
    }
    notifyListeners();
  }

  Future<void> _loadData() async {
    final data = await _api.request('bootstrap');
    current = AppUser.fromJson(data['user'] as Map<String, dynamic>);
    users = (data['users'] as List<dynamic>)
        .map((user) => AppUser.fromJson(user as Map<String, dynamic>))
        .toList();
    records = (data['records'] as List<dynamic>)
        .map((record) => CsRecord.fromJson(record as Map<String, dynamic>))
        .toList();
  }

  Future<void> _startSession(Map<String, dynamic> response) async {
    _api.token = response['token'] as String;
    await _prefs!.setString('apiToken', _api.token!);
    await _loadData();
    connectionError = null;
    notifyListeners();
  }

  Future<void> _clearToken() async {
    _api.token = null;
    await _prefs?.remove('apiToken');
    current = null;
    users = [];
    records = [];
  }

  Future<String?> login(String email, String password) async {
    connectionError = null;
    try {
      final response = await _api.request(
        'login',
        method: 'POST',
        body: {'email': email.trim(), 'password': password},
      );
      await _startSession(response);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<String?> register({
    required String name,
    required String studentNo,
    required String email,
    required String password,
  }) async {
    connectionError = null;
    try {
      final response = await _api.request(
        'register',
        method: 'POST',
        body: {
          'name': name.trim(),
          'studentNo': studentNo.trim(),
          'email': email.trim(),
          'password': password,
        },
      );
      await _startSession(response);
      return null;
    } on ApiException catch (error) {
      return error.message;
    }
  }

  Future<void> logout() async {
    try {
      await _api.request('logout', method: 'POST');
    } on ApiException catch (error) {
      connectionError = error.message;
    }
    await _clearToken();
    notifyListeners();
  }

  Future<void> updateProfile({
    required String name,
    required String email,
    required String studentNo,
    XFile? photo,
  }) async {
    await _api.updateProfile(
      name: name,
      email: email,
      studentNo: studentNo,
      photo: photo,
    );
    await _refresh();
  }

  List<AppUser> get students => users.where((user) => !user.isAdmin).toList();

  AppUser? userById(String id) {
    for (final user in users) {
      if (user.id == id) return user;
    }
    return null;
  }

  String studentName(String id) => userById(id)?.name ?? 'Unknown student';

  List<CsRecord> get visibleRecords {
    final me = current;
    if (me == null) return [];
    final visible = me.isAdmin
        ? [...records]
        : records.where((record) => record.studentId == me.id).toList();
    visible.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return visible;
  }

  Future<void> addRecord({
    required String studentId,
    required String violation,
    required double hoursRequired,
    DateTime? dutyDate,
    String dutyTime = '',
  }) async {
    await _api.request(
      'records',
      method: 'POST',
      body: {
        'studentId': studentId,
        'violation': violation.trim(),
        'hoursRequired': hoursRequired,
        'dutyDate': dutyDate?.toIso8601String().split('T').first,
        'dutyTime': dutyTime,
      },
    );
    await _refresh();
  }

  Future<void> saveRecord(CsRecord record) async {
    record.refreshStatus();
    await _api.request(
      'records',
      method: 'PUT',
      body: {
        'id': record.id,
        'studentId': record.studentId,
        'violation': record.violation,
        'hoursRequired': record.hoursRequired,
        'hoursRendered': record.hoursRendered,
        'dutyDate': record.dutyDate?.toIso8601String().split('T').first,
        'dutyTime': record.dutyTime,
      },
    );
    await _refresh();
  }

  Future<void> deleteRecord(String id) async {
    await _api.request('records', method: 'DELETE', body: {'id': id});
    await _refresh();
  }

  Future<void> reschedule(
    CsRecord record,
    DateTime date,
    String time,
    String reason,
  ) async {
    await _api.request(
      'reschedule',
      method: 'POST',
      body: {
        'id': record.id,
        'dutyDate': date.toIso8601String().split('T').first,
        'dutyTime': time,
        'note': reason,
      },
    );
    await _refresh();
  }

  Future<void> _refresh() async {
    await _loadData();
    connectionError = null;
    notifyListeners();
  }
}
