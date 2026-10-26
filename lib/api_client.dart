import 'dart:async';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient()
    : _baseUri = Uri.parse(
        const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://localhost/cs_bmc_api/index.php',
        ),
      );

  final Uri _baseUri;
  String? token;

  Uri? mediaUri(String? path) {
    if (path == null || path.isEmpty) return null;
    return _baseUri.resolve(path);
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String email,
    required String studentNo,
    XFile? photo,
  }) async {
    final request =
        http.MultipartRequest(
            'POST',
            _baseUri.replace(queryParameters: {'action': 'profile'}),
          )
          ..headers['Accept'] = 'application/json'
          ..headers['Authorization'] = 'Bearer $token'
          ..headers['X-Auth-Token'] = token ?? ''
          ..fields['name'] = name
          ..fields['email'] = email
          ..fields['studentNo'] = studentNo;

    if (photo != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'photo',
          await photo.readAsBytes(),
          filename: photo.name,
        ),
      );
    }

    try {
      final response = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final streamed = await http.Response.fromStream(response);
      final decoded = jsonDecode(streamed.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned an unreadable response.');
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw ApiException(
          (decoded['error'] as String?) ?? 'A server error occurred.',
          statusCode: streamed.statusCode,
        );
      }
      return decoded;
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the XAMPP API. Make sure Apache is running and the API URL is correct.',
      );
    } on TimeoutException {
      throw const ApiException(
        'The upload timed out. Check your connection and try again.',
      );
    } on FormatException {
      throw const ApiException(
        'The API returned invalid JSON. Check the PHP error log in XAMPP.',
      );
    }
  }

  Future<Map<String, dynamic>> request(
    String action, {
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final uri = _baseUri.replace(queryParameters: {'action': action});
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) headers['Content-Type'] = 'application/json';
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
      headers['X-Auth-Token'] = token!;
    }

    try {
      final request = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await request.send().timeout(
        const Duration(seconds: 15),
      );
      final streamed = await http.Response.fromStream(response);
      final decoded = jsonDecode(streamed.body);
      if (decoded is! Map<String, dynamic>) {
        throw const ApiException('The server returned an unreadable response.');
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        throw ApiException(
          (decoded['error'] as String?) ?? 'A server error occurred.',
          statusCode: streamed.statusCode,
        );
      }
      return decoded;
    } on http.ClientException {
      throw const ApiException(
        'Cannot reach the XAMPP API. Make sure Apache is running and the API URL is correct.',
      );
    } on TimeoutException {
      throw const ApiException(
        'The connection timed out. Make sure Apache and MySQL are running in XAMPP.',
      );
    } on FormatException {
      throw const ApiException(
        'The API returned invalid JSON. Check the PHP error log in XAMPP.',
      );
    }
  }
}
