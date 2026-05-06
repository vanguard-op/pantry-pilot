import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl, String? userId})
    : _httpClient = httpClient ?? http.Client(),
      _baseUrl = _normalizeBaseUrl(baseUrl ?? ApiConfig.defaultBaseUrl),
      _userId = userId ?? ApiConfig.defaultUserId;

  final http.Client _httpClient;
  final String _baseUrl;
  final String _userId;

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path, queryParameters: queryParameters),
      headers: _headers(),
    );
    final decoded = _decodeResponse(response);
    if (decoded is List<dynamic>) {
      return decoded;
    }
    throw ApiException('Expected a JSON list from $path.');
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _httpClient.get(
      _buildUri(path, queryParameters: queryParameters),
      headers: _headers(),
    );
    return _asObject(_decodeResponse(response), path);
  }

  Future<Map<String, dynamic>> postObject(
    String path, {
    required Object body,
  }) async {
    final response = await _httpClient.post(
      _buildUri(path),
      headers: _headers(withBody: true),
      body: jsonEncode(body),
    );
    return _asObject(_decodeResponse(response), path);
  }

  Future<Map<String, dynamic>> patchObject(
    String path, {
    required Object body,
  }) async {
    final response = await _httpClient.patch(
      _buildUri(path),
      headers: _headers(withBody: true),
      body: jsonEncode(body),
    );
    return _asObject(_decodeResponse(response), path);
  }

  Future<Map<String, dynamic>> putObject(
    String path, {
    required Object body,
  }) async {
    final response = await _httpClient.put(
      _buildUri(path),
      headers: _headers(withBody: true),
      body: jsonEncode(body),
    );
    return _asObject(_decodeResponse(response), path);
  }

  Future<void> delete(String path) async {
    final response = await _httpClient.delete(
      _buildUri(path),
      headers: _headers(),
    );
    _decodeResponse(response);
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '$_baseUrl$normalizedPath',
    ).replace(queryParameters: queryParameters);
  }

  Map<String, String> _headers({bool withBody = false}) {
    return <String, String>{
      'Accept': 'application/json',
      'X-User-Id': _userId,
      if (withBody) 'Content-Type': 'application/json',
    };
  }

  dynamic _decodeResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) {
        return null;
      }
      return jsonDecode(response.body);
    }

    final body = response.body.trim();
    throw ApiException(
      body.isEmpty
          ? 'Request failed with status ${response.statusCode}.'
          : 'Request failed with status ${response.statusCode}: $body',
    );
  }

  Map<String, dynamic> _asObject(dynamic value, String path) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, value) => MapEntry(key.toString(), value));
    }
    throw ApiException('Expected a JSON object from $path.');
  }

  static String _normalizeBaseUrl(String value) {
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }
}

class ApiConfig {
  static String get defaultBaseUrl {
    const override = String.fromEnvironment('API_BASE_URL');
    if (override.isNotEmpty) {
      return override;
    }

    if (kIsWeb) {
      return 'http://localhost:8000';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      default:
        return 'http://localhost:8000';
    }
  }

  static String get defaultUserId {
    const override = String.fromEnvironment('API_USER_ID');
    return override.isNotEmpty ? override : 'mobile-user-1';
  }
}

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
