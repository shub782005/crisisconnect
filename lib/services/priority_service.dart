// AI Priority Engine — scores community needs 0.0 to 1.0
// This is the CORE differentiator for technical judging
 
class PriorityService {
 
  /// Main scoring function — returns score 0.0 to 1.0
  /// Higher score = higher priority
  static double calculatePriorityScore({
    required String needType,
    required int peopleAffected,
    required String urgencyLevel,
    required int hoursOld, // how many hours since reported
  }) {
    // --- WEIGHT CONFIGURATION ---
    const double typeWeight       = 0.25;
    const double peopleWeight     = 0.40;
    const double urgencyWeight    = 0.25;
    const double timeDecayWeight  = 0.20;
 
    // 1. Need type score (medical > water > food > shelter > clothing)
    final double typeScore = _needTypeScore(needType);
 
    // 2. People affected score (normalized, caps at 500 people)
    final double peopleScore = (peopleAffected / 500).clamp(0.0, 1.0);
 
    // 3. Urgency level score
    final double urgencyScore = _urgencyScore(urgencyLevel);
 
    // 4. Time decay: older unresolved needs get higher priority
    final double timeScore = _timeDecayScore(hoursOld);
 
    // --- WEIGHTED COMPOSITE SCORE ---
    final double raw = (typeScore    * typeWeight)    +
                       (peopleScore  * peopleWeight)  +
                       (urgencyScore * urgencyWeight) +
                       (timeScore    * timeDecayWeight);
 
    return double.parse(raw.clamp(0.0, 1.0).toStringAsFixed(2));
  }
 
  /// Convert score to human-readable label
  static String scoreToLabel(double score) {
    if (score >= 0.70) return 'high';
    if (score >= 0.40) return 'medium';
    return 'low';
  }
 
  /// Generate human-readable explanation (Explainable AI feature)
  static String explainScore({
    required String needType,
    required int peopleAffected,
    required String urgencyLevel,
    required int hoursOld,
    required double score,
  }) {
    final List<String> reasons = [];
 
    if (needType == 'medical') reasons.add('medical emergency');
    if (needType == 'water')   reasons.add('water is critical');
    if (peopleAffected > 100)  reasons.add('$peopleAffected people affected');
    if (urgencyLevel == 'high') reasons.add('reported as urgent');
    if (hoursOld > 12)         reasons.add('waiting ${hoursOld}h');
 
    final label = scoreToLabel(score).toUpperCase();
    return '$label priority: ${reasons.join(", ")}.';
  }
 
  // --- PRIVATE HELPERS ---
 
  static double _needTypeScore(String type) {
    const scores = {
      'medical':  1.0,
      'water':    0.90,
      'food':     0.75,
      'shelter':  0.60,
      'clothing': 0.40,
    };
    return scores[type.toLowerCase()] ?? 0.50;
  }
 
  static double _urgencyScore(String level) {
    switch (level.toLowerCase()) {
      case 'high':   return 1.0;
      case 'medium': return 0.55;
      case 'low':    return 0.20;
      default:       return 0.55;
    }
  }
 
  static double _timeDecayScore(int hoursOld) {
    // Importance increases over time if still unresolved
    if (hoursOld <= 1)  return 0.20;
    if (hoursOld <= 6)  return 0.50;
    if (hoursOld <= 12) return 0.70;
    if (hoursOld <= 24) return 0.85;
    return 1.0; // Over 24h = maximum urgency
  }
}
 