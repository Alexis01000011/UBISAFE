import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';

class LocationSyncService {
  LocationSyncService(this._dio);
  final Dio _dio;

  Future<void> push(double lat, double lng) async {
    try {
      await _dio.patch<void>('/auth/location', data: {'lat': lat, 'lng': lng});
    } catch (e) {
      debugPrint('LocationSyncService.push failed: $e');
    }
  }
}

final locationSyncProvider = Provider<LocationSyncService>(
  (ref) => LocationSyncService(ref.read(apiClientProvider)),
);
