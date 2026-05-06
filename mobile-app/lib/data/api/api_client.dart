import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  ApiClient._({
    required Dio dio,
    required CacheOptions cacheOptions,
    required String userId,
  }) : _dio = dio,
       _cacheOptions = cacheOptions,
       _userId = userId;

  static Future<ApiClient> create({
    Dio? dio,
    String? baseUrl,
    String? userId,
  }) async {
    final resolvedUserId = userId ?? ApiConfig.defaultUserId;
    final resolvedBaseUrl = baseUrl ?? ApiConfig.defaultBaseUrl;
    final cacheStore = await _buildCacheStore();

    final cacheOptions = CacheOptions(
      store: cacheStore,
      policy: CachePolicy.request,
      maxStale: const Duration(days: 7),
      hitCacheOnErrorCodes: <int>[401, 403],
    );

    final builtDio = dio ?? _buildDio(resolvedBaseUrl);
    builtDio.interceptors.add(DioCacheInterceptor(options: cacheOptions));

    return ApiClient._(
      dio: builtDio,
      cacheOptions: cacheOptions,
      userId: resolvedUserId,
    );
  }

  final Dio _dio;
  final CacheOptions _cacheOptions;
  final String _userId;

  /// Shared base options - timeout, base URL, and default headers.
  static Dio _buildDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, String>{'Accept': 'application/json'},
      ),
    );
  }

  static Future<CacheStore> _buildCacheStore() async {
    if (kIsWeb) {
      return HiveCacheStore(null);
    }

    final tempDirectory = await getTemporaryDirectory();
    return HiveCacheStore('${tempDirectory.path}/dio_cache');
  }

  Future<List<dynamic>> getList(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: _options(withCache: true),
    );
    final data = response.data;
    if (data is List<dynamic>) {
      return data;
    }
    throw ApiException('Expected a JSON list from $path.');
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      options: _options(withCache: true),
    );
    return _asObject(response.data, path);
  }

  Future<Map<String, dynamic>> postObject(
    String path, {
    required Object body,
  }) async {
    final response = await _dio.post<dynamic>(
      path,
      data: body,
      options: _options(withBody: true),
    );
    return _asObject(response.data, path);
  }

  Future<Map<String, dynamic>> patchObject(
    String path, {
    required Object body,
  }) async {
    final response = await _dio.patch<dynamic>(
      path,
      data: body,
      options: _options(withBody: true),
    );
    return _asObject(response.data, path);
  }

  Future<Map<String, dynamic>> putObject(
    String path, {
    required Object body,
  }) async {
    final response = await _dio.put<dynamic>(
      path,
      data: body,
      options: _options(withBody: true),
    );
    return _asObject(response.data, path);
  }

  Future<void> delete(String path) async {
    await _dio.delete<dynamic>(path, options: _options());
  }

  /// Builds per-request [Options] carrying the user identity header.
  /// Dio automatically serializes Map/List bodies to JSON when
  /// Content-Type is application/json.
  Options _options({bool withBody = false, bool withCache = false}) {
    final requestOptions = Options(
      headers: <String, String>{
        'X-User-Id': _userId,
        if (withBody) 'Content-Type': 'application/json',
      },
    );

    if (!withCache) {
      return requestOptions;
    }

    return _cacheOptions.toOptions().copyWith(
      headers: requestOptions.headers,
      contentType: requestOptions.contentType,
    );
  }

  Map<String, dynamic> _asObject(dynamic value, String path) {
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.map((key, v) => MapEntry(key.toString(), v));
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

/// Thrown when the API returns a non-2xx status code or an unexpected shape.
///
/// Dio throws [DioException] for network/HTTP errors; this class wraps the
/// message so call-sites don't need a direct Dio dependency.
class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
