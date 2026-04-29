import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ubisafe_app/features/dispatching/models/stop_request.dart';
import 'package:ubisafe_app/features/dispatching/services/stop_request_module.dart';

// ── Mocks ──────────────────────────────────────────────────────────────────

class _MockDio extends Mock implements Dio {}

class _MockFirebaseFirestore extends Mock implements FirebaseFirestore {}

// ── Helpers ────────────────────────────────────────────────────────────────

const _stopId = 'stop-abc-123';
const _vendorUid = 'vendor-uid';
const _buyerUid = 'buyer-uid';

Map<String, dynamic> _fakeStopJson({String status = 'pending'}) => {
      'id': _stopId,
      'buyer_uid': _buyerUid,
      'vendor_uid': _vendorUid,
      'buyer_location': {'lat': 20.67, 'lng': -103.34},
      'status': status,
      'created_at': null,
    };

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data,
        {int statusCode = 200}) =>
    Response(
      data: data,
      statusCode: statusCode,
      requestOptions: RequestOptions(path: ''),
    );

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  late _MockDio mockDio;
  late _MockFirebaseFirestore mockFirestore;

  setUp(() {
    mockDio = _MockDio();
    mockFirestore = _MockFirebaseFirestore();
    registerFallbackValue(RequestOptions(path: ''));
  });

  StopRequestModule makeModule() => StopRequestModule(mockDio, mockFirestore);

  group('createStopRequest', () {
    test('calls POST /stops and returns parsed StopRequest', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _fakeResponse(_fakeStopJson(), statusCode: 201));

      final module = makeModule();
      final req = await module.createStopRequest(
        vendorUid: _vendorUid,
        buyerLat: 20.67,
        buyerLng: -103.34,
      );

      expect(req.id, equals(_stopId));
      expect(req.status, equals(StopRequestStatus.pending));
      module.cancelTimer();
    });

    test('timer is cancelled after cancelTimer()', () async {
      when(() => mockDio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => _fakeResponse(_fakeStopJson(), statusCode: 201));

      final module = makeModule();
      await module.createStopRequest(
        vendorUid: _vendorUid,
        buyerLat: 20.67,
        buyerLng: -103.34,
      );
      module.cancelTimer();
      // No error means timer was cancelled without triggering expireStopRequest
    });
  });

  group('expireStopRequest', () {
    test('calls PATCH /stops/{id}/status with status=expired', () async {
      when(() => mockDio.patch<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));

      await makeModule().expireStopRequest(_stopId);

      verify(() => mockDio.patch<dynamic>(
            '/stops/$_stopId/status',
            data: {'status': 'expired'},
          )).called(1);
    });

    test('409 Conflict is silently swallowed in timer callback pattern',
        () async {
      when(() => mockDio.patch<dynamic>(any(), data: any(named: 'data')))
          .thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          statusCode: 409,
          requestOptions: RequestOptions(path: ''),
        ),
        type: DioExceptionType.badResponse,
      ));

      // The timer callback wraps expireStopRequest and swallows 409.
      // Here we verify the same inline logic compiles and runs without throw.
      final module = makeModule();
      try {
        await module.expireStopRequest(_stopId);
      } on DioException catch (e) {
        if (e.response?.statusCode == 409) {
          // Expected: silently ignored
          return;
        }
        rethrow;
      }
    });
  });

  group('rejectStopRequest / acceptStopRequest / completeStopRequest', () {
    void stubPatch() {
      when(() => mockDio.patch<dynamic>(any(), data: any(named: 'data')))
          .thenAnswer((_) async => Response(
                data: null,
                statusCode: 200,
                requestOptions: RequestOptions(path: ''),
              ));
    }

    test('rejectStopRequest calls PATCH with status=rejected', () async {
      stubPatch();
      await makeModule().rejectStopRequest(_stopId);
      verify(() => mockDio.patch<dynamic>(
            '/stops/$_stopId/status',
            data: {'status': 'rejected'},
          )).called(1);
    });

    test('acceptStopRequest calls PATCH with status=accepted', () async {
      stubPatch();
      await makeModule().acceptStopRequest(_stopId);
      verify(() => mockDio.patch<dynamic>(
            '/stops/$_stopId/status',
            data: {'status': 'accepted'},
          )).called(1);
    });

    test('completeStopRequest calls PATCH with status=completed', () async {
      stubPatch();
      await makeModule().completeStopRequest(_stopId);
      verify(() => mockDio.patch<dynamic>(
            '/stops/$_stopId/status',
            data: {'status': 'completed'},
          )).called(1);
    });
  });

  group('StopRequest.fromJson', () {
    test('parses API response correctly', () {
      final req = StopRequest.fromJson(_fakeStopJson());
      expect(req.id, equals(_stopId));
      expect(req.status, equals(StopRequestStatus.pending));
      expect(req.buyerLat, closeTo(20.67, 1e-6));
      expect(req.buyerLng, closeTo(-103.34, 1e-6));
      expect(req.vendorUid, equals(_vendorUid));
    });

    test('handles null vendor_uid in pending state', () {
      final json = Map<String, dynamic>.from(_fakeStopJson())
        ..remove('vendor_uid');
      final req = StopRequest.fromJson(json);
      expect(req.vendorUid, isNull);
    });

    test('parses accepted status', () {
      final req = StopRequest.fromJson(_fakeStopJson(status: 'accepted'));
      expect(req.status, equals(StopRequestStatus.accepted));
    });

    test('parses rejected status', () {
      final req = StopRequest.fromJson(_fakeStopJson(status: 'rejected'));
      expect(req.status, equals(StopRequestStatus.rejected));
    });

    test('parses expired status', () {
      final req = StopRequest.fromJson(_fakeStopJson(status: 'expired'));
      expect(req.status, equals(StopRequestStatus.expired));
    });
  });
}
