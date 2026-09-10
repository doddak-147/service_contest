import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/app_config.dart';

class ApiFieldError {
  const ApiFieldError({required this.field, required this.reason});

  final String field;
  final String reason;

  factory ApiFieldError.fromJson(Map<String, dynamic> json) {
    return ApiFieldError(
      field: json['field'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }
}

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.fieldErrors = const [],
    this.requestId,
    this.statusCode,
  });

  final String code;
  final String message;
  final List<ApiFieldError> fieldErrors;
  final String? requestId;
  final int? statusCode;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _timeout = Duration(seconds: 5);

  Future<Map<String, dynamic>> getJson(String path) async {
    final decoded = await _send(
      () => _client.get(
        Uri.parse('${AppConfig.apiBaseUrl}$path'),
        headers: const {'Accept': 'application/json'},
      ),
    );
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '서버 응답 형식이 올바르지 않습니다.',
      );
    }
    return decoded;
  }

  Future<Object?> postJson(String path, Map<String, dynamic> body) {
    return _send(
      () => _client.post(
        Uri.parse('${AppConfig.apiBaseUrl}$path'),
        body: jsonEncode(body),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
  }

  Future<Object?> _send(Future<http.Response> Function() request) async {
    try {
      final response = await request().timeout(_timeout);
      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _parseError(response.statusCode, decoded);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        code: 'REQUEST_TIMEOUT',
        message: '서버 응답 시간이 초과되었습니다.',
      );
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: '서버 응답 형식이 올바르지 않습니다.',
      );
    } catch (_) {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: '서버에 연결할 수 없습니다.',
      );
    }
  }

  Object? _decode(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }
    return jsonDecode(utf8.decode(response.bodyBytes));
  }

  ApiException _parseError(int statusCode, Object? decoded) {
    if (decoded is! Map<String, dynamic>) {
      return ApiException(
        code: 'HTTP_ERROR',
        message: '서버 요청에 실패했습니다.',
        statusCode: statusCode,
      );
    }
    final error = decoded['error'];
    if (error is! Map<String, dynamic>) {
      return ApiException(
        code: 'HTTP_ERROR',
        message: '서버 요청에 실패했습니다.',
        statusCode: statusCode,
      );
    }
    final rawFieldErrors = error['field_errors'];
    final fieldErrors = rawFieldErrors is List
        ? rawFieldErrors
              .whereType<Map<String, dynamic>>()
              .map(ApiFieldError.fromJson)
              .toList(growable: false)
        : const <ApiFieldError>[];

    return ApiException(
      code: error['code'] as String? ?? 'HTTP_ERROR',
      fieldErrors: fieldErrors,
      message: error['message'] as String? ?? '서버 요청에 실패했습니다.',
      requestId: error['request_id'] as String?,
      statusCode: statusCode,
    );
  }

  void close() => _client.close();
}
