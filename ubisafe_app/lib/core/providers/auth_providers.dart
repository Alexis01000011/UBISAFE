import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_client.dart';
import '../../features/identity/auth/auth_module.dart';
import '../../features/identity/auth/models/user_profile.dart';

export '../../features/identity/auth/models/user_profile.dart';

/// Fetches the current user's profile from the API.
///
/// Returns null when unauthenticated or when no profile exists yet (404).
/// Re-evaluates whenever [authStateProvider] emits a new value.
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.valueOrNull;
  if (user == null) return null;

  final dio = ref.read(apiClientProvider);
  try {
    final response = await dio.get<Map<String, dynamic>>('/auth/me');
    return UserProfile.fromJson(response.data!);
  } on DioException catch (_) {
    // Any API or network error (404, 401 stale token, 500, timeout, connection
    // refused) → return null so the Drawer degrades gracefully instead of
    // entering the error state and showing the minimal fallback.
    return null;
  } catch (_) {
    return null;
  }
});
