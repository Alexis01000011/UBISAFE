import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _baseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8000',
);

final apiClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.addAll([
    JwtInterceptor(),
    _RetryInterceptor(dio),
  ]);

  return dio;
});

/// Injects the Firebase ID token as a Bearer header on every request.
class JwtInterceptor extends Interceptor {
  JwtInterceptor({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      } catch (_) {
        // Token refresh failed (e.g. emulator restarted, stale session).
        // Sign out so the router redirects to welcome.
        await _auth.signOut();
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // 401s are handled per-caller. Signing out globally here cascades en un
    // loop cuando endpoints no críticos (e.g. FCM token sync) devuelven 401.
    // El try-catch en onRequest ya cubre sesiones stale.
    handler.next(err);
  }
}

/// Retries failed requests up to [_maxRetries] times using exponential backoff.
/// Only retries on connection/timeout errors, not on 4xx responses.
class _RetryInterceptor extends Interceptor {
  _RetryInterceptor(this._dio);

  final Dio _dio;
  static const int _maxRetries = 3;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final retryCount = err.requestOptions.extra['_retryCount'] as int? ?? 0;
    final isNetworkError = err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout;

    if (isNetworkError && retryCount < _maxRetries) {
      await Future<void>.delayed(
        Duration(milliseconds: 300 * (1 << retryCount)),
      );
      final options = err.requestOptions
        ..extra['_retryCount'] = retryCount + 1;
      try {
        final response = await _dio.fetch<dynamic>(options);
        handler.resolve(response);
        return;
      } on DioException catch (retryErr) {
        handler.next(retryErr);
        return;
      }
    }
    handler.next(err);
  }
}
