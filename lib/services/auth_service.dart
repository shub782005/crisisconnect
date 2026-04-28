import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<UserCredential?> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    try {
      debugPrint('[AUTH] Step 1: Creating auth user...');
      final credential =
        await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      debugPrint('[AUTH] Step 1 DONE. UID=${credential.user?.uid}');

      // ✅ updateDisplayName() REMOVED — caused PigeonUserDetails crash
      // Name is stored in Firestore instead (line below)
 debugPrint('[AUTH] Step 2: Writing to Firestore...');
      await _db
        .collection('users')
        .doc(credential.user!.uid)
        .set({
          'email': email,
          'name': name,
          'role': role,
          'createdAt': FieldValue.serverTimestamp(),
        });
      debugPrint('[AUTH] Step 2 DONE. Firestore write SUCCESS!');

      return credential;

    } on FirebaseAuthException catch (e) {
      debugPrint('[AUTH] FirebaseAuthException: ${e.code}');
      throw _handleAuthError(e);
    } catch (e) {
      debugPrint('[AUTH] OTHER ERROR: $e');
      throw 'Account created but profile save failed. Try signing in.';
    }
  }

  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthError(e);
    }
  }
 Future<String> getUserRole(String uid) async {
    try {
      final doc = await _db
        .collection('users').doc(uid).get();
      return doc.data()?['role'] ?? 'volunteer';
    } catch (e) {
      return 'volunteer';
    }
  }

  // Also store name in Firestore for getUserName
  Future<String> getUserName(String uid) async {
    try {
      final doc = await _db
        .collection('users').doc(uid).get();
      return doc.data()?['name'] ?? 'User';
    } catch (e) {
      return 'User';
    }
  }

  Future<void> signOut() async =>
    await _auth.signOut();

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak.';
      case 'email-already-in-use':
        return 'Account already exists. Sign in instead.';
      case 'user-not-found':
        return 'No account found. Please sign up.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'network-request-failed':
 return 'No internet connection.';
      default:
        return 'Error: ${e.message}';
    }
  }
}