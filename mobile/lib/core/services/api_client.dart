import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kBaseUrl = 'http://localhost:4000';

class ApiClient {
  ApiClient._();

  static final Dio _dio = _createDio();

  static Dio get instance => _dio;

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) {
        debugPrintDio(error);
        handler.next(error);
      },
    ));

    return dio;
  }

  static String extractMessage(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        if (data['message'] != null) return data['message'].toString();
        if (data['error'] == 'conflict') {
          final field = data['field']?.toString();
          if (field == 'email') return 'That email address is already taken.';
          if (field == 'username') return 'That username is already taken.';
          return 'A record with those details already exists.';
        }
        if (data['error'] != null) return _mapCode(data['error'].toString());
      }
    } catch (_) {}
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return 'Connection timed out. Check your network and try again.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'Could not connect to the server. Make sure the server is running.';
    }
    return e.message ?? 'An unexpected error occurred.';
  }

  static String _mapCode(String code) {
    const map = {
      'invalid_credentials': 'Incorrect username or password.',
      'invalid_body': 'Invalid request. Please check your input.',
      'missing_token': 'Session expired. Please log in again.',
      'invalid_token': 'Session expired. Please log in again.',
      'forbidden': 'You do not have permission to do this.',
      'cannot_edit_self': 'You cannot edit your own account here.',
      'cannot_remove_self': 'You cannot remove yourself.',
      'cannot_remove_owner': 'The business owner cannot be removed.',
      'not_found': 'The requested record was not found.',
      'not_allowed': 'Access denied.',
      'missing_user': 'Session expired. Please log in again.',
      'missing_business_context': 'No active business. Please select one.',
      'internal_error': 'Server error. Please try again.',
    };
    return map[code] ?? code;
  }
}

void debugPrintDio(DioException error) {
  // ignore: avoid_print
  debugPrintThrottled(
    '[Dio Error] ${error.requestOptions.method} ${error.requestOptions.path}'
    ' → ${error.response?.statusCode}: ${error.message}',
  );
}

void debugPrintThrottled(String message) {
  // ignore: avoid_print
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}
