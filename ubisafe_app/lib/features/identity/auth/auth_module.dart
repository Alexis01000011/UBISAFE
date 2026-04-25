import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exposes the current [User] stream from Firebase Auth.
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Simple sign-in / sign-up / sign-out helpers bundled as a module.
class AuthModule {
  AuthModule(this._auth);

  final FirebaseAuth _auth;

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) =>
      _auth.createUserWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();
}

/// Riverpod provider for [AuthModule].
final authModuleProvider = Provider<AuthModule>((ref) {
  return AuthModule(FirebaseAuth.instance);
});
