import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  Future<String?> getCurrentToken() async =>
      _auth.currentUser?.getIdToken();

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  /// Creates a Firebase Auth account then syncs the profile to Firestore
  /// via POST /auth/sync-profile.
  Future<void> register({
    required String name,
    required String phone,
    required String role,
    required String email,
    required String password,
  }) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _dio.post<dynamic>('/auth/sync-profile', data: {
      'name': name,
      'phone': phone,
      'role': role,
      'email': email,
    });
  }

  Future<void> signOut() => _auth.signOut();
}

/// Riverpod provider for [AuthModule].
final authModuleProvider = Provider<AuthModule>((ref) {
  return AuthModule(FirebaseAuth.instance, ref.read(apiClientProvider));
});
