import 'dart:math';
import '../models/need_model.dart';
import '../models/volunteer_model.dart';

// ── Output types ──────────────────────────────────────────────────────────────

enum RiskLevel { critical, high, moderate, low }
enum TrendDirection { surge, rising, stable, declining }
enum PredictionConfidence { high, medium, low }

class NeedForecast {
  final String needType;
  final int predictedCount;        // next 24h
  final int predictedPeople;       // estimated people impacted
  final double probability;        // 0.0–1.0
  final PredictionConfidence confidence;
  final String reasoning;
  final List<String> driverFactors;
  final TrendDirection trend;

  const NeedForecast({
    required this.needType,
    required this.predictedCount,
    required this.predictedPeople,
    required this.probability,
    required this.confidence,
    required this.reasoning,
    required this.driverFactors,
    required this.trend,
  });
}

class EscalationAlert {
  final String title;
  final String description;
  final RiskLevel riskLevel;
  final String affectedArea;
  final List<String> triggerFactors;
  final String recommendedAction;
  final double escalationScore;    // 0.0–1.0

  const EscalationAlert({
    required this.title,
    required this.description,
    required this.riskLevel,
    required this.affectedArea,
    required this.triggerFactors,
    required this.recommendedAction,
    required this.escalationScore,
  });
}

class ResourceRecommendation {
  final String resource;
  final String action;
  final int quantity;
  final String priority;           // 'immediate' | 'soon' | 'planned'
  final String rationale;
  final String icon;

  const ResourceRecommendation({
    required this.resource,
    required this.action,
    required this.quantity,
    required this.priority,
    required this.rationale,
    required this.icon,
  });
}

class CapacityInsight {
  final double volunteerUtilisation;   // 0.0–1.0
  final int unassignedHighUrgency;
  final double avgResponseTimeHours;
  final bool capacityStrained;
  final int volunteersNeeded;
  final String recommendation;

  const CapacityInsight({
    required this.volunteerUtilisation,
    required this.unassignedHighUrgency,
    required this.avgResponseTimeHours,
    required this.capacityStrained,
    required this.volunteersNeeded,
    required this.recommendation,
  });
}

class PredictionReport {
  final DateTime generatedAt;
  final List<NeedForecast> forecasts;
  final List<EscalationAlert> escalationAlerts;
  final List<ResourceRecommendation> recommendations;
  final CapacityInsight capacityInsight;
  final String overallSummary;
  final RiskLevel overallRisk;
  final double confidenceScore;

  const PredictionReport({
    required this.generatedAt,
    required this.forecasts,
    required this.escalationAlerts,
    required this.recommendations,
    required this.capacityInsight,
    required this.overallSummary,
    required this.overallRisk,
    required this.confidenceScore,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
//  PREDICTION ENGINE
// ═══════════════════════════════════════════════════════════════════════════════

class PredictionService {

  /// Main entry point — runs all prediction modules and returns a full report
  static PredictionReport generateReport({
    required List<NeedModel> needs,
    required List<VolunteerModel> volunteers,
  }) {
    final forecasts      = _forecastNeeds(needs);
    final alerts         = _detectEscalation(needs);
    final capacity       = _analyseCapacity(needs, volunteers);
    final recommendations = _buildRecommendations(needs, volunteers, forecasts, capacity);
    final overallRisk    = _computeOverallRisk(alerts, capacity);
    final confidence     = _computeConfidence(needs);
    final summary        = _buildSummary(needs, volunteers, forecasts, alerts, overallRisk);

    return PredictionReport(
      generatedAt:      DateTime.now(),
      forecasts:        forecasts,
      escalationAlerts: alerts,
      recommendations:  recommendations,
      capacityInsight:  capacity,
      overallSummary:   summary,
      overallRisk:      overallRisk,
      confidenceScore:  confidence,
    );
  }

  // ── MODULE 1: Need Forecasting ────────────────────────────────────────────
  // Rule-based time-series pattern: analyse last 24h velocity per type,
  // apply exponential smoothing, project forward 24h.

  static List<NeedForecast> _forecastNeeds(List<NeedModel> needs) {
    final now    = DateTime.now();
    final last24 = now.subtract(const Duration(hours: 24));
    final last48 = now.subtract(const Duration(hours: 48));

    final types = ['food', 'medical', 'shelter', 'water', 'clothing'];
    final forecasts = <NeedForecast>[];

    for (final type in types) {
      final typeNeeds = needs.where((n) => n.type == type).toList();

      // Velocity: count in last 24h vs 24–48h
      final recentCount = typeNeeds.where((n) =>
        n.createdAt.isAfter(last24)).length;
      final prevCount = typeNeeds.where((n) =>
        n.createdAt.isAfter(last48) && n.createdAt.isBefore(last24)).length;

      // Exponential smoothing: α=0.7 weights recent more
      const alpha = 0.7;
      final smoothed = (alpha * recentCount + (1 - alpha) * prevCount);

      // Volatility multiplier: high-urgency pending needs signal pressure
      final pendingHigh = typeNeeds.where((n) =>
        n.urgencyLevel == 'high' && n.status == 'pending').length;
      final pressureMultiplier = 1.0 + (pendingHigh * 0.15).clamp(0, 0.6);

      final predicted = (smoothed * pressureMultiplier).ceil().clamp(0, 50);

      // People affected: weighted average from recent needs
      final avgPeople = typeNeeds.isEmpty ? 50 :
        (typeNeeds.map((n) => n.peopleAffected).reduce((a, b) => a + b) /
         typeNeeds.length).round();
      final predictedPeople = (predicted * avgPeople * 0.85).round();

      // Probability and confidence
      final probability = _typeProbability(type, recentCount, pendingHigh);
      final confidence  = _forecastConfidence(typeNeeds.length, recentCount);

      // Trend
      final trend = recentCount > prevCount * 1.2 ? TrendDirection.surge
                  : recentCount > prevCount       ? TrendDirection.rising
                  : recentCount < prevCount * 0.8 ? TrendDirection.declining
                  : TrendDirection.stable;

      // Driver factors
      final drivers = _buildDrivers(type, recentCount, pendingHigh, trend, avgPeople);

      forecasts.add(NeedForecast(
        needType:        type,
        predictedCount:  predicted,
        predictedPeople: predictedPeople,
        probability:     probability,
        confidence:      confidence,
        reasoning:       _buildForecastReasoning(type, predicted, trend, recentCount),
        driverFactors:   drivers,
        trend:           trend,
      ));
    }

    forecasts.sort((a, b) => b.probability.compareTo(a.probability));
    return forecasts;
  }

  static double _typeProbability(String type, int recentCount, int pendingHigh) {
    // Base probability by type (historical disaster patterns)
    const base = {
      'food': 0.85, 'water': 0.80, 'shelter': 0.70,
      'medical': 0.75, 'clothing': 0.55,
    };
    final b = base[type] ?? 0.5;
    final boost = min(recentCount * 0.04 + pendingHigh * 0.05, 0.20);
    return (b + boost).clamp(0.0, 0.99);
  }

  static PredictionConfidence _forecastConfidence(int total, int recent) {
    if (total >= 10 && recent >= 3) return PredictionConfidence.high;
    if (total >= 4  || recent >= 1) return PredictionConfidence.medium;
    return PredictionConfidence.low;
  }

  static List<String> _buildDrivers(String type, int recent, int pending,
      TrendDirection trend, int avgPeople) {
    final drivers = <String>[];
    if (recent > 0)  drivers.add('$recent new $type needs in last 24h');
    if (pending > 0) drivers.add('$pending high-urgency $type needs unresolved');
    if (avgPeople > 100) drivers.add('avg $avgPeople people per need');
    if (trend == TrendDirection.surge)   drivers.add('demand surging rapidly');
    if (trend == TrendDirection.rising)  drivers.add('upward trend detected');
    if (type == 'medical') drivers.add('medical needs escalate quickly');
    if (type == 'water')   drivers.add('water scarcity spreads fast');
    if (drivers.isEmpty)   drivers.add('baseline demand from historical patterns');
    return drivers;
  }

  static String _buildForecastReasoning(
      String type, int count, TrendDirection trend, int recent) {
    final trendStr = trend == TrendDirection.surge   ? 'surging demand'
                   : trend == TrendDirection.rising  ? 'rising trend'
                   : trend == TrendDirection.stable  ? 'stable pattern'
                   : 'declining trend';
    return 'Based on $trendStr and $recent recent reports, '
           'expect ~$count new $type needs in next 24 hours.';
  }

  // ── MODULE 2: Escalation Detection ───────────────────────────────────────
  // Detects when a cluster of needs signals an impending crisis spike.

  static List<EscalationAlert> _detectEscalation(List<NeedModel> needs) {
    final alerts = <EscalationAlert>[];
    final now    = DateTime.now();

    // Rule 1: Stale high-urgency needs (>6h unresolved = escalation)
    final staleHigh = needs.where((n) =>
      n.urgencyLevel == 'high' &&
      n.status == 'pending' &&
      now.difference(n.createdAt).inHours >= 6).toList();

    if (staleHigh.isNotEmpty) {
      final maxHours = staleHigh
        .map((n) => now.difference(n.createdAt).inHours)
        .reduce(max);
      alerts.add(EscalationAlert(
        title: 'Stale High-Urgency Needs',
        description: '${staleHigh.length} critical needs have been unaddressed for '
                     'over 6 hours, with the oldest at ${maxHours}h.',
        riskLevel: staleHigh.length >= 3 ? RiskLevel.critical : RiskLevel.high,
        affectedArea: _dominantArea(staleHigh),
        triggerFactors: [
          '${staleHigh.length} needs pending >6h',
          'oldest need: ${maxHours}h without response',
          'risk of community trust erosion',
        ],
        recommendedAction: 'Deploy additional volunteers immediately. '
                           'Consider reassigning idle volunteers from low-priority tasks.',
        escalationScore: (staleHigh.length * 0.15 + maxHours * 0.02).clamp(0.0, 1.0),
      ));
    }

    // Rule 2: Medical surge (>2 medical needs in last 12h)
    final medicalRecent = needs.where((n) =>
      n.type == 'medical' &&
      now.difference(n.createdAt).inHours <= 12).toList();

    if (medicalRecent.length >= 2) {
      final totalAffected = medicalRecent.fold(0, (s, n) => s + n.peopleAffected);
      alerts.add(EscalationAlert(
        title: 'Medical Emergency Cluster',
        description: '${medicalRecent.length} medical needs reported in the last 12h '
                     'affecting $totalAffected people. Possible disease outbreak or mass casualty.',
        riskLevel: medicalRecent.length >= 4 ? RiskLevel.critical : RiskLevel.high,
        affectedArea: _dominantArea(medicalRecent),
        triggerFactors: [
          '${medicalRecent.length} medical reports in 12h',
          '$totalAffected total people affected',
          'possible disease vector or mass casualty event',
        ],
        recommendedAction: 'Alert medical volunteers urgently. '
                           'Contact local health authorities. Pre-position medical supplies.',
        escalationScore: min(0.4 + medicalRecent.length * 0.15, 1.0),
      ));
    }

    // Rule 3: Volunteer capacity crunch
    final activeVolRatio = _computeVolRatio(needs);
    if (activeVolRatio > 0.80) {
      alerts.add(EscalationAlert(
        title: 'Volunteer Capacity Critical',
        description: 'Current task load is at ${(activeVolRatio * 100).toStringAsFixed(0)}% '
                     'capacity. New needs may go unaddressed.',
        riskLevel: activeVolRatio > 0.95 ? RiskLevel.critical : RiskLevel.high,
        affectedArea: 'All areas',
        triggerFactors: [
          '${(activeVolRatio * 100).toStringAsFixed(0)}% volunteer capacity used',
          'insufficient buffer for new emergencies',
          'response time will increase significantly',
        ],
        recommendedAction: 'Recruit additional volunteers via social media. '
                           'Activate standby volunteer pool. Contact partner NGOs.',
        escalationScore: activeVolRatio,
      ));
    }

    // Rule 4: Water + food combination (disaster survival critical path)
    final waterPending = needs.where((n) =>
      n.type == 'water' && n.status == 'pending').length;
    final foodPending  = needs.where((n) =>
      n.type == 'food'  && n.status == 'pending').length;

    if (waterPending >= 2 && foodPending >= 2) {
      alerts.add(EscalationAlert(
        title: 'Basic Survival Needs Unmet',
        description: '$waterPending water + $foodPending food needs simultaneously '
                     'pending — communities may face survival crisis within 24 hours.',
        riskLevel: RiskLevel.high,
        affectedArea: 'Multiple zones',
        triggerFactors: [
          '$waterPending pending water needs',
          '$foodPending pending food needs',
          'compound deprivation accelerates health risk',
        ],
        recommendedAction: 'Prioritise water first, then food. '
                           'Deploy logistics volunteers with supply vehicles.',
        escalationScore: min(0.5 + (waterPending + foodPending) * 0.06, 1.0),
      ));
    }

    // Rule 5: Rapid intake spike (>5 needs in last 2h)
    final last2h = needs.where((n) =>
      now.difference(n.createdAt).inHours <= 2).length;
    if (last2h >= 5) {
      alerts.add(EscalationAlert(
        title: 'Rapid Intake Spike',
        description: '$last2h needs reported in the last 2 hours — '
                     '${(last2h / 2.0).toStringAsFixed(1)}x the normal rate.',
        riskLevel: last2h >= 10 ? RiskLevel.critical : RiskLevel.moderate,
        affectedArea: 'Emerging zone',
        triggerFactors: [
          '$last2h needs in 2h window',
          'rate: ${last2h ~/ 2} needs/hour',
          'likely new disaster event unfolding',
        ],
        recommendedAction: 'Activate emergency response protocol. '
                           'Deploy rapid-response volunteer teams to the intake zone.',
        escalationScore: min(0.3 + last2h * 0.06, 1.0),
      ));
    }

    alerts.sort((a, b) => b.escalationScore.compareTo(a.escalationScore));
    return alerts;
  }

  // ── MODULE 3: Capacity Analysis ───────────────────────────────────────────

  static CapacityInsight _analyseCapacity(
      List<NeedModel> needs, List<VolunteerModel> volunteers) {
    final totalVols    = volunteers.length;
    final activeVols   = volunteers.where((v) => !v.isAvailable).length;
    final utilisation  = totalVols == 0 ? 0.0 : activeVols / totalVols;

    final unassignedHigh = needs.where((n) =>
      n.urgencyLevel == 'high' && n.status == 'pending').length;

    // Estimate avg response time from completed needs
    final now = DateTime.now();
    final completedWithTime = needs.where((n) =>
      n.status == 'completed').toList();
    final avgHours = completedWithTime.isEmpty ? 4.0 :
      completedWithTime.map((n) =>
        now.difference(n.createdAt).inMinutes / 60.0)
      .reduce((a, b) => a + b) / completedWithTime.length;

    // How many more volunteers needed?
    final pendingCount    = needs.where((n) => n.status == 'pending').length;
    final availableVols   = totalVols - activeVols;
    final volunteersNeeded = max(0, pendingCount - availableVols);

    final strained = utilisation > 0.75 || unassignedHigh > 2 || volunteersNeeded > 0;

    String recommendation;
    if (volunteersNeeded > 3) {
      recommendation = 'Urgently recruit $volunteersNeeded more volunteers. '
                       'Current capacity cannot handle pending needs.';
    } else if (utilisation > 0.75) {
      recommendation = 'Capacity approaching limit. Pre-recruit backup volunteers '
                       'and redistribute tasks by proximity.';
    } else if (unassignedHigh > 0) {
      recommendation = '$unassignedHigh high-urgency needs unassigned. '
                       'Prioritise reassignment of available volunteers now.';
    } else {
      recommendation = 'Capacity healthy. Monitor intake rate and maintain '
                       '$availableVols volunteers on standby.';
    }

    return CapacityInsight(
      volunteerUtilisation:  utilisation,
      unassignedHighUrgency: unassignedHigh,
      avgResponseTimeHours:  avgHours.clamp(0, 72),
      capacityStrained:      strained,
      volunteersNeeded:      volunteersNeeded,
      recommendation:        recommendation,
    );
  }

  // ── MODULE 4: Resource Recommendations ────────────────────────────────────

  static List<ResourceRecommendation> _buildRecommendations(
    List<NeedModel> needs,
    List<VolunteerModel> volunteers,
    List<NeedForecast> forecasts,
    CapacityInsight capacity,
  ) {
    final recs = <ResourceRecommendation>[];

    // Volunteer recruitment
    if (capacity.volunteersNeeded > 0) {
      recs.add(ResourceRecommendation(
        resource:  'Volunteers',
        action:    'Recruit',
        quantity:  capacity.volunteersNeeded + 2, // buffer
        priority:  capacity.volunteersNeeded > 3 ? 'immediate' : 'soon',
        rationale: '${capacity.volunteersNeeded} more needed to clear current backlog',
        icon:      '👥',
      ));
    }

    // Medical supplies (if medical forecast is high)
    final medForecast = forecasts.firstWhere(
      (f) => f.needType == 'medical',
      orElse: () => const NeedForecast(
        needType: 'medical', predictedCount: 0, predictedPeople: 0,
        probability: 0, confidence: PredictionConfidence.low,
        reasoning: '', driverFactors: [], trend: TrendDirection.stable),
    );
    if (medForecast.probability > 0.65) {
      recs.add(ResourceRecommendation(
        resource:  'Medical Kits',
        action:    'Pre-position',
        quantity:  max(5, medForecast.predictedCount * 3),
        priority:  medForecast.probability > 0.80 ? 'immediate' : 'soon',
        rationale: '${(medForecast.probability * 100).toStringAsFixed(0)}% '
                   'probability of medical surge in 24h',
        icon:      '🏥',
      ));
    }

    // Food packets
    final foodForecast = forecasts.firstWhere(
      (f) => f.needType == 'food',
      orElse: () => const NeedForecast(
        needType: 'food', predictedCount: 0, predictedPeople: 0,
        probability: 0, confidence: PredictionConfidence.low,
        reasoning: '', driverFactors: [], trend: TrendDirection.stable),
    );
    if (foodForecast.predictedPeople > 0) {
      recs.add(ResourceRecommendation(
        resource:  'Food Packets',
        action:    'Prepare',
        quantity:  (foodForecast.predictedPeople * 1.2).round(),
        priority:  foodForecast.probability > 0.75 ? 'immediate' : 'planned',
        rationale: 'Feed ~${foodForecast.predictedPeople} projected affected people',
        icon:      '🍲',
      ));
    }

    // Water cans
    final waterPending = needs.where((n) =>
      n.type == 'water' && n.status == 'pending')
      .fold(0, (s, n) => s + n.peopleAffected);
    if (waterPending > 0) {
      recs.add(ResourceRecommendation(
        resource:  'Water Cans (20L)',
        action:    'Dispatch',
        quantity:  (waterPending / 5).ceil(),
        priority:  'immediate',
        rationale: '$waterPending people currently without water',
        icon:      '💧',
      ));
    }

    // Vehicles
    final logisticsNeeds = needs.where((n) =>
      (n.type == 'food' || n.type == 'water' || n.type == 'clothing') &&
      n.status == 'pending').length;
    if (logisticsNeeds >= 3) {
      recs.add(ResourceRecommendation(
        resource:  'Logistics Vehicles',
        action:    'Mobilise',
        quantity:  max(2, logisticsNeeds ~/ 3),
        priority:  'soon',
        rationale: '$logisticsNeeds supply-delivery needs require vehicle support',
        icon:      '🚛',
      ));
    }

    // Shelter materials
    final shelterPending = needs.where((n) =>
      n.type == 'shelter' && n.status == 'pending')
      .fold(0, (s, n) => s + n.peopleAffected);
    if (shelterPending > 50) {
      recs.add(ResourceRecommendation(
        resource:  'Temporary Shelters',
        action:    'Deploy',
        quantity:  (shelterPending / 6).ceil(),
        priority:  shelterPending > 200 ? 'immediate' : 'soon',
        rationale: '$shelterPending displaced people need shelter',
        icon:      '🏕️',
      ));
    }

    // Sort: immediate > soon > planned
    const order = {'immediate': 0, 'soon': 1, 'planned': 2};
    recs.sort((a, b) =>
      (order[a.priority] ?? 3).compareTo(order[b.priority] ?? 3));

    return recs;
  }

  // ── MODULE 5: Overall Risk + Summary ─────────────────────────────────────

  static RiskLevel _computeOverallRisk(
      List<EscalationAlert> alerts, CapacityInsight capacity) {
    if (alerts.any((a) => a.riskLevel == RiskLevel.critical)) {
      return RiskLevel.critical;
    }
    if (alerts.length >= 3 || capacity.capacityStrained) {
      return RiskLevel.high;
    }
    if (alerts.isNotEmpty) return RiskLevel.moderate;
    return RiskLevel.low;
  }

  static double _computeConfidence(List<NeedModel> needs) {
    if (needs.length >= 20) return 0.88;
    if (needs.length >= 10) return 0.72;
    if (needs.length >= 5)  return 0.55;
    return 0.35;
  }

  static String _buildSummary(
    List<NeedModel> needs,
    List<VolunteerModel> volunteers,
    List<NeedForecast> forecasts,
    List<EscalationAlert> alerts,
    RiskLevel risk,
  ) {
    final pending   = needs.where((n) => n.status == 'pending').length;
    final available = volunteers.where((v) => v.isAvailable).length;
    final topForecast = forecasts.isNotEmpty ? forecasts.first : null;

    final riskStr = risk == RiskLevel.critical ? 'CRITICAL'
                  : risk == RiskLevel.high     ? 'HIGH'
                  : risk == RiskLevel.moderate ? 'MODERATE'
                  : 'LOW';

    final alertStr = alerts.isEmpty
      ? 'No escalation triggers detected.'
      : '${alerts.length} escalation alert${alerts.length > 1 ? 's' : ''} active.';

    final forecastStr = topForecast != null
      ? 'Highest predicted need: ${topForecast.needType} '
        '(${(topForecast.probability * 100).toStringAsFixed(0)}% probability).'
      : '';

    return 'Overall risk: $riskStr. $pending needs pending across all zones, '
           '$available volunteers available. $alertStr $forecastStr';
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static double _computeVolRatio(List<NeedModel> needs) {
    final pending = needs.where((n) => n.status == 'pending').length;
    // If 5+ pending needs, assume strain
    return min(pending / 5.0, 1.0);
  }

  static String _dominantArea(List<NeedModel> needs) {
    if (needs.isEmpty) return 'Unknown';
    final areas = <String, int>{};
    for (final n in needs) {
      final area = n.address.split(',').last.trim();
      areas[area] = (areas[area] ?? 0) + 1;
    }
    return areas.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }
}
