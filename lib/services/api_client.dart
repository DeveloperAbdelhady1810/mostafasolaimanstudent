import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, {this.code, this.fieldErrors = const {}});

  /// HTTP status, or 0 when there was no connection at all.
  final int status;
  final String message;
  final String? code;

  /// Laravel validation errors (HTTP 422): field name -> first message for that field.
  final Map<String, String> fieldErrors;

  bool get isOffline => status == 0;

  @override
  String toString() => 'ApiException($status${code != null ? ', $code' : ''}): $message';
}

/// Thin JSON client for the platform API. Remembers the server's clock (from the
/// HTTP `Date` header) so the rotating code stays valid even if the phone's clock is off.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
      : _http = client ?? http.Client(),
        _base = baseUrl ?? apiBaseUrl;

  final http.Client _http;
  final String _base;

  String? token;

  /// Called with (serverEpochSeconds - phoneEpochSeconds) after every response.
  void Function(int offsetSeconds)? onServerClock;

  /// Called when an authenticated request is rejected with 401 (token revoked/expired).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Map<String, dynamic>? body]) => _send('POST', path, body: body);
  Future<dynamic> delete(String path, [Map<String, dynamic>? body]) => _send('DELETE', path, body: body);

  Future<dynamic> _send(String method, String path, {Map<String, dynamic>? body}) async {
    final uri = Uri.parse('$_base$path');
    final headers = <String, String>{
      'Accept': 'application/json',
      if (body != null) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };

    http.Response res;
    try {
      final req = http.Request(method, uri)..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await _http.send(req).timeout(const Duration(seconds: 20));
      res = await http.Response.fromStream(streamed);
    } on SocketException {
      throw ApiException(0, 'offline');
    } on TimeoutException {
      throw ApiException(0, 'offline');
    } on http.ClientException {
      throw ApiException(0, 'offline');
    }

    _readServerClock(res);

    dynamic data;
    if (res.body.isNotEmpty) {
      try {
        data = jsonDecode(res.body);
      } catch (_) {
        data = null;
      }
    }

    if (res.statusCode >= 200 && res.statusCode < 300) return data;

    if (res.statusCode == 401 && token != null) onUnauthorized?.call();

    final map = data is Map ? data : const {};
    final fieldErrors = <String, String>{};
    final errors = map['errors'];
    if (errors is Map) {
      errors.forEach((field, messages) {
        final first = messages is List && messages.isNotEmpty ? messages.first : messages;
        if (first != null) fieldErrors[field.toString()] = first.toString();
      });
    }
    throw ApiException(
      res.statusCode,
      (map['message'] ?? 'Request failed').toString(),
      code: map['code']?.toString(),
      fieldErrors: fieldErrors,
    );
  }

  void _readServerClock(http.Response res) {
    final date = res.headers['date'];
    if (date == null) return;
    try {
      final server = HttpDate.parse(date).millisecondsSinceEpoch ~/ 1000;
      final phone = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      onServerClock?.call(server - phone);
    } catch (_) {}
  }
}
