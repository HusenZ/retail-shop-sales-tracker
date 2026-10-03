import 'package:dio/dio.dart';

import '../storage/token_storage.dart';
import 'api_exception.dart';

typedef Json = Map<String, dynamic>;

/// Thin wrapper over Dio: adds the auth header and turns every failure into an
/// [ApiException] so callers handle a single error type.
class ApiClient {
  ApiClient({required String baseUrl, required TokenStorage tokenStorage, Dio? dio})
      : _tokenStorage = tokenStorage,
        _dio = dio ?? Dio() {
    _dio.options
      ..baseUrl = '$baseUrl/api/v1'
      ..connectTimeout = const Duration(seconds: 10)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = Headers.jsonContentType;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.read();
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (error, handler) {
          final isLoginAttempt = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isLoginAttempt) {
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final Dio _dio;
  final TokenStorage _tokenStorage;

  /// Called when a saved token is rejected (expired or revoked).
  void Function()? onUnauthorized;

  Future<Json> getJson(String path, {Map<String, Object?>? query}) async =>
      await _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query))) as Json;

  Future<List<Json>> getJsonList(String path, {Map<String, Object?>? query}) async {
    final body = await _send(() => _dio.get<dynamic>(path, queryParameters: _clean(query)));
    return (body as List<dynamic>).cast<Json>();
  }

  Future<Json> postJson(String path, {Object? body}) async =>
      await _send(() => _dio.post<dynamic>(path, data: body)) as Json;

  Future<Json> patchJson(String path, {Object? body}) async =>
      await _send(() => _dio.patch<dynamic>(path, data: body)) as Json;

  Future<void> delete(String path) async {
    await _send(() => _dio.delete<dynamic>(path));
  }

  Future<Object?> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return response.data as Object?;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  static Map<String, Object?>? _clean(Map<String, Object?>? query) {
    if (query == null) return null;
    return {
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value.toString(),
    };
  }
}
