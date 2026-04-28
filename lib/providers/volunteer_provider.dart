import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';
import '../services/matching_service.dart';

class VolunteerProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _firestoreService = FirestoreService();

  List<VolunteerModel> _volunteers = [];
  bool _isLoading = false;

  List<VolunteerModel> get volunteers => _volunteers;
  bool get isLoading => _isLoading;

  // Load all volunteers from Firestore
  Future<void> loadVolunteers() async {
    _isLoading = true; notifyListeners();
    try {
      _volunteers = await _firestoreService.getAvailableVolunteers();
    } finally {
      _isLoading = false; notifyListeners();
    }
  }

  // Register volunteer profile in Firestore after signup
  Future<void> registerVolunteer({
    required String uid,
    required String name,
    required String email,
    required String phone,
    required List<String> skills,
    required double lat,
    required double lng,
  }) async {
    final volunteer = VolunteerModel(
      id: uid, name: name, email: email,
      phone: phone, lat: lat, lng: lng,
      skills: skills, isAvailable: true,
      activeTasks: 0, completedTasks: 0,
      trustScore: 0.5,
    );
    await _db.collection('volunteers')
      .doc(uid).set(volunteer.toFirestore());
  }

  // Get best match for a need — returns ranked list
  List<MatchResult> getBestMatches(needModel) {
    return MatchingService.findBestVolunteers(
      need: needModel,
      volunteers: _volunteers,
    );
  }
}