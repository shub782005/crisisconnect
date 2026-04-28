import 'package:flutter/material.dart';
import '../models/need_model.dart';
import '../models/volunteer_model.dart';
import '../services/prediction_service.dart';
import '../services/firestore_service.dart';

class PredictionProvider extends ChangeNotifier {
  final _db = FirestoreService();

  PredictionReport? _report;
  bool _isLoading = false;
  String? _error;
  DateTime? _lastGenerated;

  PredictionReport? get report        => _report;
  bool              get isLoading     => _isLoading;
  String?           get error         => _error;
  DateTime?         get lastGenerated => _lastGenerated;

  bool get hasReport => _report != null;

  Future<void> generateReport({
    required List<NeedModel> needs,
    required List<VolunteerModel> volunteers,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Small delay for UX — feels like it's computing
      await Future.delayed(const Duration(milliseconds: 800));

      _report        = PredictionService.generateReport(
        needs: needs, volunteers: volunteers);
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadAndGenerate() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.delayed(const Duration(milliseconds: 600));

      final needsSnap = await _db.getNeedsStream().first;
      final volunteers = await _db.getAvailableVolunteers();

      _report        = PredictionService.generateReport(
        needs: needsSnap, volunteers: volunteers);
      _lastGenerated = DateTime.now();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    _report = null;
    notifyListeners();
  }
}
