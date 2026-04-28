// Smart Volunteer Matching — the other core AI feature
import 'dart:math';
import '../models/need_model.dart';
import '../models/volunteer_model.dart';
 
class MatchResult {
  final String volunteerId;
  final String volunteerName;
  final double matchScore;
  final String explanation; // EXPLAINABILITY
  final double distanceKm;
 
  MatchResult({
    required this.volunteerId,
    required this.volunteerName,
    required this.matchScore,
    required this.explanation,
    required this.distanceKm,
  });
}
 
class MatchingService {
 
  /// Returns ranked list of best volunteers for a given need
  static List<MatchResult> findBestVolunteers({
    required NeedModel need,
    required List<VolunteerModel> volunteers,
    int topN = 3,
  }) {
    final results = <MatchResult>[];
 
    for (final volunteer in volunteers) {
      if (!volunteer.isAvailable) continue;
      if (volunteer.activeTasks >= 3) continue; // Workload cap
 
      final score = _calculateMatchScore(need, volunteer);
      final distance = _haversineDistance(
        need.lat, need.lng, volunteer.lat, volunteer.lng
      );
      final explanation = _buildExplanation(need, volunteer, score, distance);
 
      results.add(MatchResult(
        volunteerId: volunteer.id,
        volunteerName: volunteer.name,
        matchScore: score,
        explanation: explanation,
        distanceKm: distance,
      ));
    }
 
    // Sort by score descending
    results.sort((a, b) => b.matchScore.compareTo(a.matchScore));
    return results.take(topN).toList();
  }
 
  static double _calculateMatchScore(NeedModel need, VolunteerModel volunteer) {
    const double distanceWeight     = 0.35;
    const double skillWeight        = 0.30;
    const double availabilityWeight = 0.20;
    const double trustWeight        = 0.15;
 
    // 1. Distance score (closer = better, 0-20km range)
    final double distKm = _haversineDistance(
      need.lat, need.lng, volunteer.lat, volunteer.lng
    );
    final double distScore = (1 - (distKm / 20)).clamp(0.0, 1.0);
 
    // 2. Skill match score
    final double skillScore = _skillMatchScore(need.type, volunteer.skills);
 
    // 3. Availability / workload score
    final double loadScore = 1 - (volunteer.activeTasks / 3);
 
    // 4. Trust score (from past performance)
    final double trustScore = volunteer.trustScore;
 
    final double raw = (distScore  * distanceWeight)    +
                       (skillScore * skillWeight)        +
                       (loadScore  * availabilityWeight) +
                       (trustScore * trustWeight);
 
    return double.parse(raw.clamp(0.0, 1.0).toStringAsFixed(2));
  }
 
  static String _buildExplanation(
    NeedModel need,
    VolunteerModel volunteer,
    double score,
    double distanceKm,
  ) {
    final reasons = <String>[];
    if (distanceKm < 3)  reasons.add('very close (${distanceKm.toStringAsFixed(1)}km)');
    if (distanceKm < 10) reasons.add('nearby (${distanceKm.toStringAsFixed(1)}km)');
    if (_skillMatchScore(need.type, volunteer.skills) > 0.7) {
      reasons.add('has ${need.type} skills');
    }
    if (volunteer.activeTasks == 0) reasons.add('fully available');
    if (volunteer.trustScore > 0.8) reasons.add('highly trusted');
    return 'Matched: ${reasons.join(", ")}.';
  }
 
  static double _skillMatchScore(String needType, List<String> skills) {
    // Mapping of need types to relevant skills
    const skillMap = {
      'medical':  ['medical', 'first_aid', 'nursing', 'doctor'],
      'food':     ['cooking', 'food_distribution', 'logistics'],
      'shelter':  ['construction', 'logistics', 'driving'],
      'water':    ['logistics', 'driving', 'water_management'],
      'clothing': ['logistics', 'distribution'],
    };
    final requiredSkills = skillMap[needType.toLowerCase()] ?? [];
    if (requiredSkills.isEmpty) return 0.5;
 
    int matches = 0;
    for (final skill in skills) {
      if (requiredSkills.contains(skill.toLowerCase())) matches++;
    }
    return (matches / requiredSkills.length).clamp(0.0, 1.0);
  }
 
  /// Haversine formula — calculates distance between two GPS coordinates
  static double _haversineDistance(
    double lat1, double lng1, double lat2, double lng2
  ) {
    const double earthRadius = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
              cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
              sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }
 
  static double _deg2rad(double deg) => deg * (pi / 180);
}
 