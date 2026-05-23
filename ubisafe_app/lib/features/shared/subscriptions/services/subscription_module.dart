import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_client.dart';
import '../models/subscription.dart';

class SubscriptionModule {
  SubscriptionModule(this._dio);

  final Dio _dio;

  Future<List<Subscription>> listActive() async {
    final res = await _dio.get<List<dynamic>>('/subscriptions');
    return (res.data ?? [])
        .cast<Map<String, dynamic>>()
        .map(Subscription.fromJson)
        .toList();
  }

  Future<Subscription> subscribe(String vendorUid) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/subscriptions',
      data: {'vendor_uid': vendorUid},
    );
    return Subscription.fromJson(res.data!);
  }

  Future<void> unsubscribe(String subscriptionId) async {
    await _dio.delete<void>('/subscriptions/$subscriptionId');
  }
}

final subscriptionModuleProvider = Provider<SubscriptionModule>((ref) {
  return SubscriptionModule(ref.read(apiClientProvider));
});
