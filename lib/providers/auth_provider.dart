// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../providers/needs_provider.dart';

class AuthProvider extends ChangeNotifier {
  final _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters — screens read these
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null;
  bool get isAdmin => _currentUser?.isAdmin ?? false;

  // Called on signup — creates account + saves role
  Future<bool> signUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    _setLoading(true);
    try {
      final credential = await _authService.signUp(
        email: email, password: password,
        name: name, role: role,
      );
      if (credential != null) {
        await _loadUser(credential.user!.uid);
        
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Called on login
Future<bool> signIn({
  required String email,
  required String password,
}) async {
  _setLoading(true);
  try {
    final credential = await _authService.signIn(
      email: email, password: password,
    );
    if (credential != null) {
      // Read BOTH role and name from Firestore
      final uid = credential.user!.uid;
      final role = await _authService.getUserRole(uid);
      final name = await _authService.getUserName(uid);
      _currentUser = UserModel(
        id: uid,
        email: email,
        name: name,
        role: role,
        createdAt: DateTime.now(),
      );
      notifyListeners();
      return true;
    }
    return false;
  } catch (e) {
 _errorMessage = e.toString();
    notifyListeners();
    return false;
  } finally {
    _setLoading(false);
  }
}

  Future<void> signOut() async {
    await _authService.signOut();
    _currentUser = null;
    notifyListeners();
  }

  // Reads user doc from Firestore after login
  Future<void> _loadUser(String uid) async {
    final role = await _authService.getUserRole(uid);
    final firebaseUser = _authService.currentUser!;
    _currentUser = UserModel(
      id: uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      role: role,
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  void _setLoading(bool val) {
    _isLoading = val;
    _errorMessage = null;
    notifyListeners();
  }
}