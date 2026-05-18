import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';

/// Exposes the current [User] stream from Firebase Auth.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Sign-in / sign-up / sign-out helpers.
class AuthModule {
  AuthModule(this._auth, this._dio);

  final FirebaseAuth _auth;
  final Dio _dio;

  Future<String?> getCurrentToken() async => _auth.currentUser?.getIdToken();

  /// Signs in and then syncs the profile timestamp + FCM token (SDD §8.4.B).
  Future<void> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // firebase_auth 4.16.0 on Android has a Pigeon serialisation bug where
      // signInWithEmailAndPassword throws a type-cast error even though the
      // sign-in itself succeeded and the auth state was updated.
      // If the user is now authenticated we ignore the exception and continue;
      // otherwise we rethrow so the caller sees the real error.
      if (_auth.currentUser == null) rethrow;
    }
    // Both calls are best-effort — run in the background so login() returns
    // immediately after sign-in, preventing the UI from blocking on network.
    unawaited(
      Future<void>(() async {
        try {
          await _dio.post<dynamic>('/auth/sync-profile', data: <String, dynamic>{});
        } catch (_) {}
      }),
    );
    unawaited(_syncDeviceToken());
  }

  /// Creates a Firebase Auth account, syncs the profile to Firestore,
  /// and registers the FCM device token (SDD §8.4.A).
  Future<void> register({
    required String name,
    required String phone,
    required String role,
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      // firebase_auth 4.16.0 on Android: same Pigeon deserialisation bug as
      // signIn — account IS created but a type-cast exception is thrown.
      // If currentUser is not null the account exists — continue normally.
      if (_auth.currentUser == null) rethrow;
    }
    await _dio.post<dynamic>('/auth/sync-profile', data: {
      'name': name,
      'phone': phone,
      'role': role,
    });
    await _syncDeviceToken();
  }

  Future<void> signOut() => _auth.signOut();

  /// Gets the current FCM token and registers it with the backend.
  /// Best-effort: silently ignored if the token is unavailable.
  Future<void> _syncDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _dio.patch<dynamic>('/auth/device-token', data: {'token': token});
      }
    } catch (_) {
      // Non-critical — NotificationHandler will retry on next app start.
    }
  }
}

/// Riverpod provider for [AuthModule].
final authModuleProvider = Provider<AuthModule>((ref) {
  return AuthModule(FirebaseAuth.instance, ref.read(apiClientProvider));
});
