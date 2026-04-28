import 'package:flutter/material.dart';
import '../models/need_model.dart';
import '../models/volunteer_model.dart';
import '../services/firestore_service.dart';

enum UrgencyFilter { all, high, medium, low }
enum TypeFilter    { all, food, medical, shelter, water, clothing }

class MapProvider extends ChangeNotifier {
  final _firestoreService = FirestoreService();

  List<NeedModel>      _needs      = [];
  List<VolunteerModel> _volunteers = [];
  bool          _isLoading       = false;
  bool          _showVolunteers  = true;
  bool          _showHeatmap     = true;
  bool          _showMarkers     = true;
  UrgencyFilter _urgencyFilter   = UrgencyFilter.all;
  TypeFilter    _typeFilter      = TypeFilter.all;
  NeedModel?    _selectedNeed;

  // ── Getters ───────────────────────────────────────────────────────────────
  List<NeedModel>      get allNeeds     => _needs;
  List<VolunteerModel> get volunteers   => _volunteers;
  bool                 get isLoading    => _isLoading;
  bool                 get showVolunteers => _showVolunteers;
  bool                 get showHeatmap  => _showHeatmap;
  bool                 get showMarkers  => _showMarkers;
  UrgencyFilter        get urgencyFilter => _urgencyFilter;
  TypeFilter           get typeFilter   => _typeFilter;
  NeedModel?           get selectedNeed => _selectedNeed;

  List<NeedModel> get filteredNeeds {
    var list = _needs.where((n) => n.status != 'completed').toList();
    if (_urgencyFilter != UrgencyFilter.all) {
      list = list.where((n) => n.urgencyLevel == _urgencyFilter.name).toList();
    }
    if (_typeFilter != TypeFilter.all) {
      list = list.where((n) => n.type == _typeFilter.name).toList();
    }
    return list;
  }

  List<NeedModel> get heatmapNeeds => _needs.where((n) {
    if (_urgencyFilter != UrgencyFilter.all) {
      return n.urgencyLevel == _urgencyFilter.name;
    }
    return true;
  }).toList();

  // ── Stats ─────────────────────────────────────────────────────────────────
  int get highCount   => _needs.where((n) => n.urgencyLevel == 'high'   && n.status != 'completed').length;
  int get mediumCount => _needs.where((n) => n.urgencyLevel == 'medium' && n.status != 'completed').length;
  int get lowCount    => _needs.where((n) => n.urgencyLevel == 'low'    && n.status != 'completed').length;
  int get totalPeopleAffected => filteredNeeds.fold(0, (s, n) => s + n.peopleAffected);

  // ── Data loading ──────────────────────────────────────────────────────────
  void startListening() {
    _isLoading = true;
    notifyListeners();
    _firestoreService.getNeedsStream().listen(
      (needs) { _needs = needs; _isLoading = false; notifyListeners(); },
      onError: (_)  { _isLoading = false; notifyListeners(); },
    );
  }

  Future<void> loadVolunteers() async {
    try {
      _volunteers = await _firestoreService.getAvailableVolunteers();
      notifyListeners();
    } catch (_) {}
  }

  // ── Filter controls ───────────────────────────────────────────────────────
  void setUrgencyFilter(UrgencyFilter f) { _urgencyFilter = f; notifyListeners(); }
  void setTypeFilter(TypeFilter f)       { _typeFilter    = f; notifyListeners(); }
  void toggleVolunteers() { _showVolunteers = !_showVolunteers; notifyListeners(); }
  void toggleHeatmap()    { _showHeatmap    = !_showHeatmap;    notifyListeners(); }
  void toggleMarkers()    { _showMarkers    = !_showMarkers;    notifyListeners(); }

  // ── Selection ─────────────────────────────────────────────────────────────
  void selectNeed(NeedModel? need) { _selectedNeed = need; notifyListeners(); }
  void clearSelection()            { _selectedNeed = null; notifyListeners(); }
}
