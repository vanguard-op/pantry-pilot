import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:http_cache_hive_store/http_cache_hive_store.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class ApiClient {
  /// [tokenProvider] is called before every request. It should return:
  /// - A Cognito access token string in production / staging.
  /// - `null` to fall back to the local-dev [ApiConfig.defaultUserId] header.
  ApiClient._({
    required Dio dio,
    required CacheOptions cacheOptions,
    required Future<String?> Function() tokenProvider,
  }) : _dio = dio,
       _cacheOptions = cacheOptions,
       _tokenProvider = tokenProvider;

  static Future<ApiClient> create({
    Dio? dio,
    String? baseUrl,
    Future<String?> Function()? tokenProvider,
  }) async {
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
      tokenProvider: tokenProvider ?? () async => null,
    );
  }

  final Dio _dio;
  final CacheOptions _cacheOptions;
  final Future<String?> Function() _tokenProvider;

  /// Shared base options - timeout, base URL, and default headers.
  static Dio _buildDio(String baseUrl) {
    return Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 30),
        headers: <String, String>{'Accept': 'application/json'},
        // Handle non-2xx statuses ourselves so we can raise domain exceptions.
        validateStatus: (_) => true,
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
    final response = await _safeRequest(
      method: 'GET',
      path: path,
      run: () async => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: await _options(withCache: true),
      ),
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
    final response = await _safeRequest(
      method: 'GET',
      path: path,
      run: () async => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: await _options(withCache: true),
      ),
    );
    return _asObject(response.data, path);
  }

  Future<Map<String, dynamic>> postObject(
    String path, {
    required Object body,
  }) async {
    final response = await _safeRequest(
      method: 'POST',
      path: path,
      run: () async => _dio.post<dynamic>(
        path,
        data: body,
        options: await _options(withBody: true),
      ),
    );
    return _asObject(response.data, path);
  }

  Future<List<dynamic>> postList(String path, {required Object body}) async {
    final response = await _safeRequest(
      method: 'POST',
      path: path,
      run: () async => _dio.post<dynamic>(
        path,
        data: body,
        options: await _options(withBody: true),
      ),
    );
    final data = response.data;
    if (data is List<dynamic>) {
      return data;
    }
    throw ApiException('Expected a JSON list from $path.');
  }

  Future<Map<String, dynamic>> patchObject(
    String path, {
    required Object body,
  }) async {
    final response = await _safeRequest(
      method: 'PATCH',
      path: path,
      run: () async => _dio.patch<dynamic>(
        path,
        data: body,
        options: await _options(withBody: true),
      ),
    );
    return _asObject(response.data, path);
  }

  Future<Map<String, dynamic>> putObject(
    String path, {
    required Object body,
  }) async {
    final response = await _safeRequest(
      method: 'PUT',
      path: path,
      run: () async => _dio.put<dynamic>(
        path,
        data: body,
        options: await _options(withBody: true),
      ),
    );
    return _asObject(response.data, path);
  }

  Future<void> delete(String path) async {
    await _safeRequest(
      method: 'DELETE',
      path: path,
      run: () async => _dio.delete<dynamic>(path, options: await _options()),
    );
  }

  Future<Response<dynamic>> _safeRequest({
    required String method,
    required String path,
    required Future<Response<dynamic>> Function() run,
  }) async {
    try {
      final response = await run();
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        throw ApiException.fromResponse(
          method: method,
          path: path,
          response: response,
        );
      }
      return response;
    } on DioException catch (error) {
      throw ApiException.fromDioException(
        method: method,
        path: path,
        error: error,
      );
    }
  }

  /// Builds per-request [Options].
  ///
  /// In production the [_tokenProvider] returns a Cognito access token which
  /// is sent as `Authorization: Bearer <token>`.  In local dev it returns null
  /// and we fall back to the `X-User-Id` header so the backend's dev fallback
  /// path is exercised without standing up a real Cognito pool.
  Future<Options> _options({
    bool withBody = false,
    bool withCache = false,
  }) async {
    final token = await _tokenProvider();
    final headers = <String, String>{
      if (token != null)
        'Authorization': 'Bearer $token'
      else
        'X-User-Id': ApiConfig.defaultUserId,
      if (withBody) 'Content-Type': 'application/json',
    };

    final requestOptions = Options(headers: headers);
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

  factory ApiException.fromResponse({
    required String method,
    required String path,
    required Response<dynamic> response,
  }) {
    final statusCode = response.statusCode ?? 0;
    final detail = _extractDetail(response.data);

    if (statusCode == 401) {
      final suffix = (detail != null && detail.isNotEmpty)
          ? ' Details: $detail'
          : '';
      return ApiException(
        'Unauthorized ($method $path). Sign in again and verify Cognito configuration.$suffix',
      );
    }

    final suffix = (detail != null && detail.isNotEmpty)
        ? ' Details: $detail'
        : '';
    return ApiException(
      'Request failed with HTTP $statusCode ($method $path).$suffix',
    );
  }

  factory ApiException.fromDioException({
    required String method,
    required String path,
    required DioException error,
  }) {
    return ApiException(
      'Network error while calling $method $path: ${error.message ?? 'unknown error'}',
    );
  }

  final String message;

  static String? _extractDetail(dynamic responseData) {
    if (responseData is Map) {
      final detail = responseData['detail']?.toString();
      if (detail != null && detail.isNotEmpty) {
        return detail;
      }
      return null;
    }

    if (responseData is String && responseData.isNotEmpty) {
      return responseData;
    }

    return null;
  }

  @override
  String toString() => message;
}
