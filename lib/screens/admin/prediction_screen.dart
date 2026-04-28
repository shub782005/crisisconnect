import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/prediction_provider.dart';
import '../../providers/needs_provider.dart';
import '../../providers/volunteer_provider.dart';
import '../../services/prediction_service.dart';

class PredictionScreen extends StatefulWidget {
  const PredictionScreen({super.key});
  @override
  State<PredictionScreen> createState() => _PredictionScreenState();
}

class _PredictionScreenState extends State<PredictionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NeedsProvider>().startListening();
      _generate();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    // Ensure volunteers are loaded
    final volProvider = context.read<VolunteerProvider>();
    if (volProvider.volunteers.isEmpty) {
      await volProvider.loadVolunteers();
    }
    if (!mounted) return;
    final needs      = context.read<NeedsProvider>().needs;
    final volunteers = volProvider.volunteers;
    await context.read<PredictionProvider>().generateReport(
      needs: needs, volunteers: volunteers);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PredictionProvider>(
      builder: (context, pred, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('AI Prediction Engine'),
            backgroundColor: const Color(0xFF4A148C),
            foregroundColor: Colors.white,
            actions: [
              if (pred.lastGenerated != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Center(
                    child: Text(
                      'Updated ${_timeAgo(pred.lastGenerated!)}',
                      style: const TextStyle(fontSize: 10, color: Colors.white60)),
                  ),
                ),
              IconButton(
                icon: pred.isLoading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.refresh),
                onPressed: pred.isLoading ? null : _generate,
                tooltip: 'Re-run predictions',
              ),
            ],
            bottom: pred.hasReport ? TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              isScrollable: true,
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.psychology, size: 14), text: 'Overview'),
                Tab(icon: Icon(Icons.trending_up, size: 14), text: 'Forecasts'),
                Tab(icon: Icon(Icons.warning_amber, size: 14), text: 'Alerts'),
                Tab(icon: Icon(Icons.inventory_2, size: 14), text: 'Resources'),
              ],
            ) : null,
          ),
          body: pred.isLoading
            ? _LoadingView()
            : pred.error != null
              ? _ErrorView(error: pred.error!, onRetry: _generate)
              : !pred.hasReport
                ? _EmptyView(onGenerate: _generate)
                : TabBarView(
                    controller: _tabs,
                    children: [
                      _OverviewTab(report: pred.report!),
                      _ForecastTab(report: pred.report!),
                      _AlertsTab(report: pred.report!),
                      _ResourcesTab(report: pred.report!),
                    ],
                  ),
        );
      },
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60)  return 'just now';
    if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  LOADING
// ═══════════════════════════════════════════════════════════════════════════════
class _LoadingView extends StatefulWidget {
  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _pulse;
  int _step = 0;

  final _steps = [
    '🔍 Analysing historical need patterns...',
    '📈 Running exponential smoothing forecasts...',
    '⚡ Detecting escalation risk signals...',
    '🧠 Generating resource recommendations...',
    '✅ Compiling prediction report...',
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    // Step through messages
    _cycleSteps();
  }

  void _cycleSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (mounted) setState(() => _step = i);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: _pulse,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(
                  color: const Color(0xFF4A148C).withValues(alpha: 0.4),
                  blurRadius: 20, spreadRadius: 4)],
              ),
              child: const Icon(Icons.psychology, color: Colors.white, size: 40),
            ),
          ),
          const SizedBox(height: 28),
          const Text('Running AI Prediction Engine',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
              color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Analysing patterns across all zones',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 28),
          // Step progress
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8)],
            ),
            child: Column(children: [
              for (int i = 0; i < _steps.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: i < _step
                        ? const Icon(Icons.check_circle,
                            size: 16, color: AppColors.urgencyLow)
                        : i == _step
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(
                                color: Color(0xFF4A148C), strokeWidth: 2))
                          : Icon(Icons.radio_button_unchecked,
                              size: 16, color: Colors.grey.shade300),
                    ),
                    const SizedBox(width: 10),
                    Text(_steps[i], style: TextStyle(
                      fontSize: 12,
                      color: i <= _step
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                      fontWeight: i == _step
                        ? FontWeight.w600 : FontWeight.normal)),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  ERROR / EMPTY
// ═══════════════════════════════════════════════════════════════════════════════
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.urgencyHigh),
        const SizedBox(height: 12),
        const Text('Prediction failed', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(error, textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4A148C),
            foregroundColor: Colors.white),
        ),
      ]),
    ),
  );
}

class _EmptyView extends StatelessWidget {
  final VoidCallback onGenerate;
  const _EmptyView({required this.onGenerate});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.psychology_alt, size: 64, color: Color(0xFF4A148C)),
      const SizedBox(height: 16),
      const Text('Run AI Predictions', style: TextStyle(
        fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('Forecasts, escalation alerts and\nresource recommendations',
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary)),
      const SizedBox(height: 20),
      ElevatedButton.icon(
        onPressed: onGenerate,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Generate Report'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4A148C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
      ),
    ]),
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1: OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final PredictionReport report;
  const _OverviewTab({required this.report});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── Overall risk card ───────────────────────────────────────────
        _RiskBanner(risk: report.overallRisk, summary: report.overallSummary,
          confidence: report.confidenceScore),

        const SizedBox(height: 16),

        // ── Capacity gauge ──────────────────────────────────────────────
        const _SectionLabel(icon: Icons.people_alt, label: 'Volunteer Capacity'),
        const SizedBox(height: 10),
        _CapacityCard(insight: report.capacityInsight),

        const SizedBox(height: 16),

        // ── Top 3 forecasts mini-list ───────────────────────────────────
        const _SectionLabel(icon: Icons.trending_up, label: 'Top Predicted Needs (24h)'),
        const SizedBox(height: 10),
        for (final f in report.forecasts.take(3))
          _ForecastMiniCard(forecast: f),

        const SizedBox(height: 16),

        // ── Active alerts summary ───────────────────────────────────────
        _SectionLabel(icon: Icons.warning_amber,
          label: 'Escalation Alerts (${report.escalationAlerts.length})'),
        const SizedBox(height: 10),
        if (report.escalationAlerts.isEmpty)
          _GreenClearCard()
        else
          for (final a in report.escalationAlerts.take(2))
            _AlertMiniCard(alert: a),

        const SizedBox(height: 24),
      ]),
    );
  }
}

// ── Risk banner ──────────────────────────────────────────────────────────────
class _RiskBanner extends StatelessWidget {
  final RiskLevel risk;
  final String summary;
  final double confidence;
  const _RiskBanner({required this.risk, required this.summary, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = _riskColor(risk);
    final label = _riskLabel(risk);
    final emoji = _riskEmoji(risk);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.35),
          blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('OVERALL RISK: $label',
                style: const TextStyle(
                  color: Colors.white, fontSize: 13,
                  fontWeight: FontWeight.bold, letterSpacing: 1)),
              Text('AI Confidence: ${(confidence * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20)),
            child: Text(label,
              style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ]),
        const SizedBox(height: 12),
        Container(height: 1, color: Colors.white24),
        const SizedBox(height: 10),
        Text(summary,
          style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
      ]),
    );
  }

  Color  _riskColor(RiskLevel r) {
    switch (r) {
      case RiskLevel.critical: return const Color(0xFFB71C1C);
      case RiskLevel.high:     return AppColors.urgencyHigh;
      case RiskLevel.moderate: return AppColors.urgencyMedium;
      case RiskLevel.low:      return AppColors.urgencyLow;
    }
  }
  String _riskLabel(RiskLevel r) {
    switch (r) {
      case RiskLevel.critical: return 'CRITICAL';
      case RiskLevel.high:     return 'HIGH';
      case RiskLevel.moderate: return 'MODERATE';
      case RiskLevel.low:      return 'LOW';
    }
  }
  String _riskEmoji(RiskLevel r) {
    switch (r) {
      case RiskLevel.critical: return '🔴';
      case RiskLevel.high:     return '🟠';
      case RiskLevel.moderate: return '🟡';
      case RiskLevel.low:      return '🟢';
    }
  }
}

// ── Capacity card ─────────────────────────────────────────────────────────────
class _CapacityCard extends StatelessWidget {
  final CapacityInsight insight;
  const _CapacityCard({required this.insight});

  @override
  Widget build(BuildContext context) {
    final utilPct = (insight.volunteerUtilisation * 100).toStringAsFixed(0);
    final utilColor = insight.volunteerUtilisation > 0.85
      ? AppColors.urgencyHigh
      : insight.volunteerUtilisation > 0.65
        ? AppColors.urgencyMedium
        : AppColors.urgencyLow;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecor(),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('$utilPct%', style: TextStyle(
                  fontSize: 32, fontWeight: FontWeight.bold, color: utilColor)),
                const SizedBox(width: 8),
                const Text('utilised', style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
              ]),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: LinearProgressIndicator(
                  value: insight.volunteerUtilisation,
                  minHeight: 10,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(utilColor),
                ),
              ),
            ],
          )),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _CapStat('Avg Response',
              '${insight.avgResponseTimeHours.toStringAsFixed(1)}h'),
            const SizedBox(height: 6),
            _CapStat('Unassigned High',
              '${insight.unassignedHighUrgency}'),
            const SizedBox(height: 6),
            _CapStat('Vols Needed',
              '${insight.volunteersNeeded}',
              highlight: insight.volunteersNeeded > 0),
          ]),
        ]),
        if (insight.capacityStrained) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.urgencyHigh.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.urgencyHigh.withValues(alpha: 0.25))),
            child: Row(children: [
              const Icon(Icons.warning_amber,
                size: 14, color: AppColors.urgencyHigh),
              const SizedBox(width: 8),
              Expanded(child: Text(insight.recommendation,
                style: const TextStyle(
                  fontSize: 11, color: AppColors.textPrimary))),
            ]),
          ),
        ] else ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.check_circle,
              size: 14, color: AppColors.urgencyLow),
            const SizedBox(width: 6),
            Expanded(child: Text(insight.recommendation,
              style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary))),
          ]),
        ],
      ]),
    );
  }
}

class _CapStat extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _CapStat(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(value, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold,
        color: highlight ? AppColors.urgencyHigh : AppColors.textPrimary)),
      Text(label, style: const TextStyle(
        fontSize: 9, color: AppColors.textSecondary)),
    ]);
}

class _GreenClearCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.urgencyLow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.urgencyLow.withValues(alpha: 0.3))),
    child: const Row(children: [
      Icon(Icons.check_circle, color: AppColors.urgencyLow, size: 20),
      SizedBox(width: 10),
      Text('No escalation triggers detected — situation stable',
        style: TextStyle(fontSize: 13, color: AppColors.urgencyLow,
          fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── Forecast mini card ───────────────────────────────────────────────────────
class _ForecastMiniCard extends StatelessWidget {
  final NeedForecast forecast;
  const _ForecastMiniCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final trendIcon = _trendIcon(forecast.trend);
    final trendColor = _trendColor(forecast.trend);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: _cardDecor(),
      child: Row(children: [
        Text(_typeEmoji(forecast.needType),
          style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_cap(forecast.needType),
              style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
            Text('~${forecast.predictedCount} new needs · '
                 '~${forecast.predictedPeople} people',
              style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${(forecast.probability * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16,
              color: AppColors.primary)),
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(trendIcon, size: 11, color: trendColor),
            const SizedBox(width: 2),
            Text(_trendLabel(forecast.trend),
              style: TextStyle(fontSize: 9, color: trendColor)),
          ]),
        ]),
      ]),
    );
  }
}

// ── Alert mini card ──────────────────────────────────────────────────────────
class _AlertMiniCard extends StatelessWidget {
  final EscalationAlert alert;
  const _AlertMiniCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = _riskLevelColor(alert.riskLevel);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(children: [
        Icon(_riskLevelIcon(alert.riskLevel), color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(alert.title, style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 12, color: color)),
            Text(alert.affectedArea, style: const TextStyle(
              fontSize: 10, color: AppColors.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Text(_riskLevelLabel(alert.riskLevel),
            style: TextStyle(fontSize: 9,
              fontWeight: FontWeight.bold, color: color)),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2: FORECASTS
// ═══════════════════════════════════════════════════════════════════════════════
class _ForecastTab extends StatelessWidget {
  final PredictionReport report;
  const _ForecastTab({required this.report});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF4A148C).withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF4A148C).withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.info_outline, size: 14, color: Color(0xFF4A148C)),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Forecasts use exponential smoothing on the last 48h of data '
              'with a pressure multiplier for unresolved high-urgency needs.',
              style: TextStyle(fontSize: 11, color: AppColors.textPrimary))),
          ]),
        ),
        const SizedBox(height: 16),
        for (final forecast in report.forecasts)
          _ForecastDetailCard(forecast: forecast),
      ],
    );
  }
}

class _ForecastDetailCard extends StatelessWidget {
  final NeedForecast forecast;
  const _ForecastDetailCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final trendColor = _trendColor(forecast.trend);
    final confColor  = forecast.confidence == PredictionConfidence.high
      ? AppColors.urgencyLow
      : forecast.confidence == PredictionConfidence.medium
        ? AppColors.urgencyMedium
        : AppColors.textSecondary;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecor(),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
          child: Row(children: [
            Text(_typeEmoji(forecast.needType),
              style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cap(forecast.needType),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15)),
                Row(children: [
                  Icon(_trendIcon(forecast.trend), size: 12, color: trendColor),
                  const SizedBox(width: 3),
                  Text(_trendLabel(forecast.trend),
                    style: TextStyle(fontSize: 11, color: trendColor,
                      fontWeight: FontWeight.w500)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${(forecast.probability * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
              const Text('probability', style: TextStyle(
                fontSize: 9, color: AppColors.textSecondary)),
            ]),
          ]),
        ),

        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Stat row
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _FStat('${forecast.predictedCount}', 'New Needs', AppColors.primary),
              _FStat('${forecast.predictedPeople}', 'People', AppColors.urgencyHigh),
              _FStat(_confidenceLabel(forecast.confidence), 'Confidence', confColor),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Reasoning
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.auto_awesome, size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(forecast.reasoning,
                style: const TextStyle(
                  fontSize: 12, color: AppColors.textPrimary, height: 1.4))),
            ]),

            const SizedBox(height: 10),

            // Driver factors
            const Text('KEY DRIVERS', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold,
              letterSpacing: 1, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            for (final d in forecast.driverFactors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(children: [
                  Container(width: 4, height: 4,
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    decoration: const BoxDecoration(
                      color: AppColors.primary, shape: BoxShape.circle)),
                  Expanded(child: Text(d, style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary))),
                ]),
              ),
          ]),
        ),
      ]),
    );
  }
}

class _FStat extends StatelessWidget {
  final String value, label;
  final Color color;
  const _FStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(
      fontSize: 18, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: const TextStyle(
      fontSize: 9, color: AppColors.textSecondary)),
  ]);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 3: ALERTS
// ═══════════════════════════════════════════════════════════════════════════════
class _AlertsTab extends StatelessWidget {
  final PredictionReport report;
  const _AlertsTab({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.escalationAlerts.isEmpty) {
      return const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.verified_outlined, size: 64, color: AppColors.urgencyLow),
        SizedBox(height: 12),
        Text('No Escalation Threats', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('All rule-based detectors are clear.\nContinue monitoring.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary)),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final alert in report.escalationAlerts)
          _AlertDetailCard(alert: alert),
      ],
    );
  }
}

class _AlertDetailCard extends StatelessWidget {
  final EscalationAlert alert;
  const _AlertDetailCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = _riskLevelColor(alert.riskLevel);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: _cardDecor(),
      clipBehavior: Clip.hardEdge,
      child: Column(children: [
        // Coloured top stripe
        Container(
          height: 5,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withValues(alpha: 0.5)])),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Title row
            Row(children: [
              Icon(_riskLevelIcon(alert.riskLevel), color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(child: Text(alert.title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.4))),
                child: Text(_riskLevelLabel(alert.riskLevel),
                  style: TextStyle(fontSize: 10,
                    fontWeight: FontWeight.bold, color: color)),
              ),
            ]),
            const SizedBox(height: 8),

            // Escalation score bar
            Row(children: [
              const Text('Escalation risk:', style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              Expanded(child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: alert.escalationScore,
                  minHeight: 7,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              )),
              const SizedBox(width: 6),
              Text('${(alert.escalationScore * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11,
                  fontWeight: FontWeight.bold, color: color)),
            ]),

            const SizedBox(height: 10),
            Text(alert.description,
              style: const TextStyle(
                fontSize: 12, color: AppColors.textPrimary, height: 1.4)),

            const SizedBox(height: 12),

            // Area
            Row(children: [
              const Icon(Icons.location_on, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Affected area: ${alert.affectedArea}',
                style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
            ]),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Trigger factors
            const Text('TRIGGER FACTORS', style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold,
              letterSpacing: 1, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            for (final t in alert.triggerFactors)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(children: [
                  Container(width: 4, height: 4,
                    margin: const EdgeInsets.only(right: 8, top: 2),
                    decoration: BoxDecoration(
                      color: color, shape: BoxShape.circle)),
                  Expanded(child: Text(t, style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary))),
                ]),
              ),

            const SizedBox(height: 10),

            // Recommended action
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color.withValues(alpha: 0.25))),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.lightbulb_outline, size: 14, color: color),
                const SizedBox(width: 8),
                Expanded(child: Text(alert.recommendedAction,
                  style: const TextStyle(
                    fontSize: 12, color: AppColors.textPrimary, height: 1.4))),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 4: RESOURCES
// ═══════════════════════════════════════════════════════════════════════════════
class _ResourcesTab extends StatelessWidget {
  final PredictionReport report;
  const _ResourcesTab({required this.report});

  @override
  Widget build(BuildContext context) {
    if (report.recommendations.isEmpty) {
      return const Center(child: Text('No resource actions needed.',
        style: TextStyle(color: AppColors.textSecondary)));
    }

    const order = {'immediate': 0, 'soon': 1, 'planned': 2};
    final grouped = <String, List<ResourceRecommendation>>{};
    for (final r in report.recommendations) {
      grouped.putIfAbsent(r.priority, () => []).add(r);
    }
    final keys = grouped.keys.toList()
      ..sort((a, b) => (order[a] ?? 3).compareTo(order[b] ?? 3));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final key in keys) ...[
          _PriorityGroupHeader(priority: key),
          const SizedBox(height: 8),
          for (final rec in grouped[key]!)
            _ResourceCard(rec: rec),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PriorityGroupHeader extends StatelessWidget {
  final String priority;
  const _PriorityGroupHeader({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label, emoji;
    switch (priority) {
      case 'immediate': color = AppColors.urgencyHigh;   label = 'IMMEDIATE ACTION'; emoji = '🚨'; break;
      case 'soon':      color = AppColors.urgencyMedium; label = 'SOON';             emoji = '⏰'; break;
      default:          color = AppColors.urgencyLow;    label = 'PLANNED';          emoji = '📋';
    }
    return Row(children: [
      Text(emoji),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold,
        letterSpacing: 1, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.3))),
    ]);
  }
}

class _ResourceCard extends StatelessWidget {
  final ResourceRecommendation rec;
  const _ResourceCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final priorityColor = rec.priority == 'immediate'
      ? AppColors.urgencyHigh
      : rec.priority == 'soon'
        ? AppColors.urgencyMedium
        : AppColors.urgencyLow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecor(),
      child: Row(children: [
        Text(rec.icon, style: const TextStyle(fontSize: 28)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(rec.action, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: priorityColor, letterSpacing: 0.5)),
              const SizedBox(width: 6),
              Expanded(child: Text(rec.resource,
                style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 3),
            Text(rec.rationale, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${rec.quantity}', style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.bold,
            color: AppColors.primary)),
          const Text('units', style: TextStyle(
            fontSize: 9, color: AppColors.textSecondary)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
BoxDecoration _cardDecor() => BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(12),
  boxShadow: [BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 8, offset: const Offset(0, 2))],
);

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 15, color: const Color(0xFF4A148C)),
    const SizedBox(width: 7),
    Text(label, style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
  ]);
}

String _typeEmoji(String type) {
  switch (type) {
    case 'food':     return '🍲';
    case 'medical':  return '🏥';
    case 'shelter':  return '🏠';
    case 'water':    return '💧';
    case 'clothing': return '👕';
    default:         return '📦';
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _trendLabel(TrendDirection t) {
  switch (t) {
    case TrendDirection.surge:    return 'Surging';
    case TrendDirection.rising:   return 'Rising';
    case TrendDirection.stable:   return 'Stable';
    case TrendDirection.declining: return 'Declining';
  }
}

IconData _trendIcon(TrendDirection t) {
  switch (t) {
    case TrendDirection.surge:    return Icons.trending_up;
    case TrendDirection.rising:   return Icons.arrow_upward;
    case TrendDirection.stable:   return Icons.remove;
    case TrendDirection.declining: return Icons.trending_down;
  }
}

Color _trendColor(TrendDirection t) {
  switch (t) {
    case TrendDirection.surge:    return AppColors.urgencyHigh;
    case TrendDirection.rising:   return AppColors.urgencyMedium;
    case TrendDirection.stable:   return AppColors.textSecondary;
    case TrendDirection.declining: return AppColors.urgencyLow;
  }
}

Color _riskLevelColor(RiskLevel r) {
  switch (r) {
    case RiskLevel.critical: return const Color(0xFFB71C1C);
    case RiskLevel.high:     return AppColors.urgencyHigh;
    case RiskLevel.moderate: return AppColors.urgencyMedium;
    case RiskLevel.low:      return AppColors.urgencyLow;
  }
}

IconData _riskLevelIcon(RiskLevel r) {
  switch (r) {
    case RiskLevel.critical: return Icons.crisis_alert;
    case RiskLevel.high:     return Icons.warning_amber;
    case RiskLevel.moderate: return Icons.info_outline;
    case RiskLevel.low:      return Icons.check_circle_outline;
  }
}

String _riskLevelLabel(RiskLevel r) {
  switch (r) {
    case RiskLevel.critical: return 'CRITICAL';
    case RiskLevel.high:     return 'HIGH';
    case RiskLevel.moderate: return 'MODERATE';
    case RiskLevel.low:      return 'LOW';
  }
}

String _confidenceLabel(PredictionConfidence c) {
  switch (c) {
    case PredictionConfidence.high:   return 'High';
    case PredictionConfidence.medium: return 'Medium';
    case PredictionConfidence.low:    return 'Low';
  }
}
