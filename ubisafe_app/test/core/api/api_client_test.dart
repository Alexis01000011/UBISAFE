import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ubisafe_app/core/api/api_client.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUser extends Mock implements User {}

class _FakeRequestHandler extends Fake implements RequestInterceptorHandler {
  RequestOptions? captured;

  @override
  void next(RequestOptions options) => captured = options;
}

class _FakeErrorHandler extends Fake implements ErrorInterceptorHandler {
  DioException? captured;

  @override
  void next(DioException err) => captured = err;
}

void main() {
  group('JwtInterceptor', () {
    late _MockFirebaseAuth mockAuth;
    late JwtInterceptor interceptor;

    setUp(() {
      mockAuth = _MockFirebaseAuth();
      interceptor = JwtInterceptor(auth: mockAuth);
    });

    test('no añade Authorization cuando currentUser es null', () async {
      when(() => mockAuth.currentUser).thenReturn(null);

      final options = RequestOptions(path: '/test');
      final handler = _FakeRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.captured?.headers.containsKey('Authorization'), isFalse);
    });

    test('añade Bearer token cuando el usuario está logueado', () async {
      final mockUser = _MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken(any()))
          .thenAnswer((_) async => 'test.jwt.token');

      final options = RequestOptions(path: '/test');
      final handler = _FakeRequestHandler();

      await interceptor.onRequest(options, handler);

      expect(handler.captured?.headers['Authorization'],
          equals('Bearer test.jwt.token'));
    });

    test('onError no llama signOut y propaga el error', () {
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final err = DioException(
        requestOptions: RequestOptions(path: '/test'),
        response: Response(
          requestOptions: RequestOptions(path: '/test'),
          statusCode: 401,
        ),
      );
      final handler = _FakeErrorHandler();

      interceptor.onError(err, handler);

      verifyNever(() => mockAuth.signOut());
      expect(handler.captured, same(err));
    });

    test('hace signOut silencioso cuando getIdToken falla', () async {
      final mockUser = _MockUser();
      when(() => mockAuth.currentUser).thenReturn(mockUser);
      when(() => mockUser.getIdToken(any()))
          .thenThrow(Exception('token error'));
      when(() => mockAuth.signOut()).thenAnswer((_) async {});

      final options = RequestOptions(path: '/test');
      final handler = _FakeRequestHandler();

      await interceptor.onRequest(options, handler);

      verify(() => mockAuth.signOut()).called(1);
      expect(handler.captured, isNotNull);
      expect(handler.captured?.headers.containsKey('Authorization'), isFalse);
    });
  });
}
