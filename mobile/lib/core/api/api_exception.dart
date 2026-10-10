import 'package:dio/dio.dart';

/// An error the user can understand, raised for any failed API call.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) return const ApiException(noConnectionMessage);
    return ApiException(
      messageFromBody(response.data) ??
          'Something went wrong (${response.statusCode}). Please try again.',
      statusCode: response.statusCode,
    );
  }

  static const noConnectionMessage = 'No internet connection. Check your network and try again.';

  final String message;

  /// Null when the server could not be reached at all.
  final int? statusCode;

  bool get isNetworkError => statusCode == null;
  bool get isNotFound => statusCode == 404;
  bool get isUnauthorized => statusCode == 401;

  /// Reads FastAPI's `detail`, which is a string for business errors and a list
  /// of field errors for validation failures.
  static String? messageFromBody(Object? body) {
    if (body is! Map) return null;
    final detail = body['detail'];
    if (detail is String) return detail;
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] is String) {
        return (first['msg'] as String).replaceFirst('Value error, ', '');
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
