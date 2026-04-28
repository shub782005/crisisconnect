import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../services/notification_service.dart';
import '../../widgets/stat_counter.dart';

class ImpactAnalyticsScreen extends StatefulWidget {
  const ImpactAnalyticsScreen({super.key});
  @override
  State<ImpactAnalyticsScreen> createState() => _ImpactAnalyticsScreenState();
}

class _ImpactAnalyticsScreenState extends State<ImpactAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  // Stats
  int _totalNeeds        = 0;
  int _completedNeeds    = 0;
  int _pendingNeeds      = 0;
  int _assignedNeeds     = 0;
  int _peopleHelped      = 0;
  int _totalPeopleAtRisk = 0;
  int _totalVolunteers   = 0;
  int _activeVolunteers  = 0;
  double _avgResponseMin = 0;
  double _completionRate = 0;

  // Charts
  Map<String, int> _needsByType     = {};
  Map<String, int> _needsByUrgency  = {};
  List<_DailyCount> _completedPerDay = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadStats();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    final db = FirebaseFirestore.instance;

    try {
      // ── Needs ──────────────────────────────────────────────────────────
      final needsSnap = await db.collection('needs').get();
      final needs = needsSnap.docs;

      int completed = 0, pending = 0, assigned = 0;
      int peopleHelped = 0, totalAtRisk = 0;
      final byType    = <String, int>{};
      final byUrgency = <String, int>{};
      final perDay    = <String, int>{};
      double totalMinutes = 0;
      int timedCount = 0;

      for (final doc in needs) {
        final data   = doc.data();
        final status = data['status'] as String? ?? 'pending';
        final type   = data['type']   as String? ?? 'other';
        final urgency = data['urgencyLevel'] as String? ?? 'medium';
        final people = data['peopleAffected'] as int? ?? 0;

        totalAtRisk += people;
        byType[type]       = (byType[type]       ?? 0) + 1;
        byUrgency[urgency] = (byUrgency[urgency] ?? 0) + 1;

        if (status == 'completed') {
          completed++;
          peopleHelped += people;

          // Response time: assignedAt - createdAt
          final createdAt  = (data['createdAt']  as Timestamp?)?.toDate();
          final updatedAt  = (data['updatedAt']  as Timestamp?)?.toDate();
          if (createdAt != null && updatedAt != null) {
            totalMinutes += updatedAt.difference(createdAt).inMinutes;
            timedCount++;
          }

          // Group by day (last 7 days)
          final completedAt = updatedAt ?? DateTime.now();
          final dayKey = '${completedAt.month}/${completedAt.day}';
          perDay[dayKey] = (perDay[dayKey] ?? 0) + 1;
        } else if (status == 'pending')  { pending++;  }
        else if (status == 'assigned' || status == 'on_the_way') { assigned++; }
      }

      // ── Volunteers ─────────────────────────────────────────────────────
      final volSnap = await db.collection('volunteers').get();
      final active  = volSnap.docs
        .where((d) => d.data()['isAvailable'] == true).length;

      // Build last-7-days series
      final now = DateTime.now();
      final series = <_DailyCount>[];
      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final key = '${day.month}/${day.day}';
        series.add(_DailyCount(
          label: _dayLabel(day),
          count: perDay[key] ?? 0,
        ));
      }

      setState(() {
        _totalNeeds        = needs.length;
        _completedNeeds    = completed;
        _pendingNeeds      = pending;
        _assignedNeeds     = assigned;
        _peopleHelped      = peopleHelped;
        _totalPeopleAtRisk = totalAtRisk;
        _totalVolunteers   = volSnap.docs.length;
        _activeVolunteers  = active;
        _avgResponseMin    = timedCount > 0 ? totalMinutes / timedCount : 0;
        _completionRate    = needs.isEmpty ? 0 : completed / needs.length;
        _needsByType       = byType;
        _needsByUrgency    = byUrgency;
        _completedPerDay   = series;
        _isLoading         = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  String _dayLabel(DateTime d) {
    const days = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return days[d.weekday - 1];
  }

  // ── Test notification ────────────────────────────────────────────────────
  Future<void> _testNotification(String type) async {
    switch (type) {
      case 'urgent':
        await NotificationService.broadcastCrisisAlert(
          needType: 'Medical', location: 'Kolhapur Relief Camp',
          peopleAffected: 250);
        break;
      case 'assigned':
        await NotificationService.notifyTaskAssigned(
          volunteerName: 'Priya Sharma', needType: 'food',
          urgencyLevel: 'high', location: 'Sangli District');
        break;
      case 'completed':
        await NotificationService.notifyTaskCompleted(
          volunteerName: 'Rahul Patil', needType: 'water',
          peopleHelped: 120);
        break;
      case 'reminder':
        await NotificationService.notifyTaskReminder(
          needType: 'shelter', location: 'Satara Camp');
        break;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Test notification sent!'),
        backgroundColor: AppColors.urgencyLow,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Impact Tracker'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStats,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(icon: Icon(Icons.bar_chart, size: 16), text: 'Overview'),
            Tab(icon: Icon(Icons.pie_chart, size: 16),  text: 'Breakdown'),
            Tab(icon: Icon(Icons.notifications, size: 16), text: 'Alerts'),
          ],
        ),
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : TabBarView(
            controller: _tabs,
            children: [
              _OverviewTab(this),
              _BreakdownTab(this),
              _AlertsTab(onTest: _testNotification),
            ],
          ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final _ImpactAnalyticsScreenState s;
  const _OverviewTab(this.s);

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: s._loadStats,
      color: AppColors.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

          // ── Hero stats grid ─────────────────────────────────────────────
          const _SectionHeader(icon: Icons.emoji_events, title: 'Relief Impact'),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              _StatCard(
                color: const Color(0xFF1565C0),
                icon: Icons.people,
                child: StatCounter(
                  value: s._peopleHelped,
                  label: 'People Helped',
                  color: Colors.white,
                  fontSize: 26,
                ),
              ),
              _StatCard(
                color: AppColors.urgencyLow,
                icon: Icons.task_alt,
                child: StatCounter(
                  value: s._completedNeeds,
                  label: 'Needs Resolved',
                  color: Colors.white,
                  fontSize: 26,
                ),
              ),
              _StatCard(
                color: AppColors.secondary,
                icon: Icons.volunteer_activism,
                child: StatCounter(
                  value: s._totalVolunteers,
                  label: 'Volunteers',
                  color: Colors.white,
                  fontSize: 26,
                ),
              ),
              _StatCard(
                color: const Color(0xFF6A1B9A),
                icon: Icons.speed,
                child: StatCounter(
                  value: s._avgResponseMin.toInt(),
                  label: 'Avg Response (min)',
                  color: Colors.white,
                  fontSize: 26,
                  suffix: 'm',
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Completion rate bar ──────────────────────────────────────────
          const _SectionHeader(icon: Icons.donut_large, title: 'Completion Rate'),
          const SizedBox(height: 12),
          _CompletionRateCard(rate: s._completionRate, completed: s._completedNeeds, total: s._totalNeeds),

          const SizedBox(height: 20),

          // ── Pipeline status ──────────────────────────────────────────────
          const _SectionHeader(icon: Icons.view_kanban, title: 'Need Pipeline'),
          const SizedBox(height: 12),
          _PipelineCard(
            pending:   s._pendingNeeds,
            assigned:  s._assignedNeeds,
            completed: s._completedNeeds,
            total:     s._totalNeeds,
          ),

          const SizedBox(height: 20),

          // ── 7-day bar chart ──────────────────────────────────────────────
          const _SectionHeader(icon: Icons.timeline, title: 'Resolutions — Last 7 Days'),
          const SizedBox(height: 12),
          _BarChartCard(data: s._completedPerDay),

          const SizedBox(height: 20),

          // ── Volunteer availability ───────────────────────────────────────
          const _SectionHeader(icon: Icons.people_alt, title: 'Volunteer Force'),
          const SizedBox(height: 12),
          _VolunteerCard(
            total: s._totalVolunteers,
            active: s._activeVolunteers,
          ),

          const SizedBox(height: 24),
        ]),
      ),
    );
  }
}

// ── Completion Rate Card ─────────────────────────────────────────────────────
class _CompletionRateCard extends StatelessWidget {
  final double rate;
  final int completed, total;
  const _CompletionRateCard({required this.rate, required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = (rate * 100).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$pct%', style: const TextStyle(
                fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.urgencyLow)),
              Text('$completed of $total needs resolved',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
          SizedBox(
            width: 64, height: 64,
            child: CircularProgressIndicator(
              value: rate,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: const AlwaysStoppedAnimation(AppColors.urgencyLow),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: rate,
            minHeight: 10,
            backgroundColor: Colors.grey.shade100,
            valueColor: const AlwaysStoppedAnimation(AppColors.urgencyLow),
          ),
        ),
      ]),
    );
  }
}

// ── Pipeline Card ────────────────────────────────────────────────────────────
class _PipelineCard extends StatelessWidget {
  final int pending, assigned, completed, total;
  const _PipelineCard({required this.pending, required this.assigned,
    required this.completed, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _PipelineStep(
          count: pending, label: 'Pending',
          color: AppColors.urgencyHigh, icon: Icons.pending_actions),
        _Arrow(),
        _PipelineStep(
          count: assigned, label: 'Assigned',
          color: AppColors.urgencyMedium, icon: Icons.assignment_ind),
        _Arrow(),
        _PipelineStep(
          count: completed, label: 'Done',
          color: AppColors.urgencyLow, icon: Icons.task_alt),
      ]),
    );
  }
}

class _PipelineStep extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  final IconData icon;
  const _PipelineStep({required this.count, required this.label,
    required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 22),
      ),
      const SizedBox(height: 6),
      Text('$count', style: TextStyle(
        fontSize: 20, fontWeight: FontWeight.bold, color: color)),
      Text(label, style: const TextStyle(
        fontSize: 10, color: AppColors.textSecondary)),
    ]);
  }
}

class _Arrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    const Icon(Icons.arrow_forward, size: 16, color: AppColors.textSecondary);
}

// ── Bar Chart Card ───────────────────────────────────────────────────────────
class _BarChartCard extends StatelessWidget {
  final List<_DailyCount> data;
  const _BarChartCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.map((d) => d.count).fold(0, (a, b) => a > b ? a : b);
    final adjustedMax = (maxY + 2).toDouble();

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: BarChart(
        BarChartData(
          maxY: adjustedMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                BarTooltipItem(
                  '${rod.toY.toInt()} resolved',
                  const TextStyle(color: Colors.white, fontSize: 11),
                ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                getTitlesWidget: (v, _) => v % 1 == 0
                  ? Text('${v.toInt()}', style: const TextStyle(
                      fontSize: 9, color: AppColors.textSecondary))
                  : const SizedBox.shrink(),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(data[i].label,
                      style: const TextStyle(
                        fontSize: 9, color: AppColors.textSecondary)),
                  );
                },
              ),
            ),
            rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: Colors.grey.shade100, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((e) =>
            BarChartGroupData(
              x: e.key,
              barRods: [
                BarChartRodData(
                  toY: e.value.count.toDouble(),
                  color: AppColors.primary,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: adjustedMax,
                    color: Colors.grey.shade50,
                  ),
                ),
              ],
            ),
          ).toList(),
        ),
      ),
    );
  }
}

// ── Volunteer Card ───────────────────────────────────────────────────────────
class _VolunteerCard extends StatelessWidget {
  final int total, active;
  const _VolunteerCard({required this.total, required this.active});

  @override
  Widget build(BuildContext context) {
    final inactive = total - active;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$total Total', style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            _VolBar(label: 'Available', count: active, total: total,
              color: AppColors.urgencyLow),
            const SizedBox(height: 4),
            _VolBar(label: 'Busy', count: inactive, total: total,
              color: AppColors.urgencyMedium),
          ]),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 70, height: 70,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: total == 0 ? 0 : active / total,
              strokeWidth: 10,
              backgroundColor: AppColors.urgencyMedium.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation(AppColors.urgencyLow),
            ),
            Text('$active\navail',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold,
                color: AppColors.urgencyLow)),
          ]),
        ),
      ]),
    );
  }
}

class _VolBar extends StatelessWidget {
  final String label;
  final int count, total;
  final Color color;
  const _VolBar({required this.label, required this.count,
    required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(children: [
      SizedBox(width: 60,
        child: Text(label, style: const TextStyle(
          fontSize: 11, color: AppColors.textSecondary))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
      ),
      const SizedBox(width: 6),
      Text('$count', style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — BREAKDOWN
// ═══════════════════════════════════════════════════════════════════════════════
class _BreakdownTab extends StatelessWidget {
  final _ImpactAnalyticsScreenState s;
  const _BreakdownTab(this.s);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // ── People at risk vs helped ─────────────────────────────────────
        const _SectionHeader(icon: Icons.favorite, title: 'People Impact'),
        const SizedBox(height: 12),
        _PeopleImpactCard(
          atRisk: s._totalPeopleAtRisk,
          helped: s._peopleHelped),

        const SizedBox(height: 20),

        // ── Needs by type ────────────────────────────────────────────────
        const _SectionHeader(icon: Icons.category, title: 'Needs by Type'),
        const SizedBox(height: 12),
        _DonutChart(
          data: s._needsByType,
          colors: const [
            Color(0xFF1565C0), Color(0xFFE53935), Color(0xFF43A047),
            Color(0xFF00897B), Color(0xFF6A1B9A),
          ],
          icons: const {
            'food': Icons.restaurant,
            'medical': Icons.local_hospital,
            'shelter': Icons.home,
            'water': Icons.water_drop,
            'clothing': Icons.checkroom,
          },
        ),

        const SizedBox(height: 20),

        // ── Needs by urgency ─────────────────────────────────────────────
        const _SectionHeader(icon: Icons.warning_amber, title: 'Needs by Urgency'),
        const SizedBox(height: 12),
        _UrgencyBreakdownCard(data: s._needsByUrgency),

        const SizedBox(height: 24),
      ]),
    );
  }
}

class _PeopleImpactCard extends StatelessWidget {
  final int atRisk, helped;
  const _PeopleImpactCard({required this.atRisk, required this.helped});

  @override
  Widget build(BuildContext context) {
    final pct = atRisk == 0 ? 0.0 : (helped / atRisk).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _ImpactNum(value: helped, label: 'People Helped', color: Colors.white),
          Container(width: 1, height: 50, color: Colors.white30),
          _ImpactNum(value: atRisk, label: 'Total Affected', color: Colors.white70),
        ]),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 10,
            backgroundColor: Colors.white24,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text('${(pct * 100).toStringAsFixed(1)}% of affected people reached',
          style: const TextStyle(
            color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}

class _ImpactNum extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _ImpactNum({required this.value, required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text('$value', style: TextStyle(
      fontSize: 28, fontWeight: FontWeight.bold, color: color)),
    Text(label, style: TextStyle(fontSize: 11, color: color)),
  ]);
}

// ── Donut chart ──────────────────────────────────────────────────────────────
class _DonutChart extends StatelessWidget {
  final Map<String, int> data;
  final List<Color> colors;
  final Map<String, IconData> icons;
  const _DonutChart({required this.data, required this.colors, required this.icons});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const _EmptyChart();
    final entries = data.entries.toList();
    final total   = data.values.fold(0, (a, b) => a + b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        SizedBox(
          width: 130, height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 36,
              sections: entries.asMap().entries.map((e) {
                final color = colors[e.key % colors.length];
                return PieChartSectionData(
                  value: e.value.value.toDouble(),
                  color: color,
                  radius: 28,
                  showTitle: false,
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: entries.asMap().entries.map((e) {
              final color = colors[e.key % colors.length];
              final pct   = total == 0 ? 0.0 : e.value.value / total * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Icon(icons[e.value.key] ?? Icons.help,
                    size: 12, color: color),
                  const SizedBox(width: 4),
                  Expanded(child: Text(
                    _cap(e.value.key),
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary))),
                  Text('${e.value.value}',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                  Text(' (${pct.toStringAsFixed(0)}%)',
                    style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
                ]),
              );
            }).toList(),
          ),
        ),
      ]),
    );
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ── Urgency breakdown ────────────────────────────────────────────────────────
class _UrgencyBreakdownCard extends StatelessWidget {
  final Map<String, int> data;
  const _UrgencyBreakdownCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        for (final level in ['high', 'medium', 'low']) ...[
          _UrgencyRow(
            level: level,
            count: data[level] ?? 0,
            total: total),
          if (level != 'low') const SizedBox(height: 10),
        ],
      ]),
    );
  }
}

class _UrgencyRow extends StatelessWidget {
  final String level;
  final int count, total;
  const _UrgencyRow({required this.level, required this.count, required this.total});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.urgencyColor(level);
    final pct   = total == 0 ? 0.0 : count / total;
    return Row(children: [
      Container(
        width: 8, height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 8),
      SizedBox(width: 50,
        child: Text(_cap(level), style: const TextStyle(
          fontSize: 12, color: AppColors.textPrimary))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 10,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Text('$count', style: TextStyle(
        fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    ]);
  }

  String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ═══════════════════════════════════════════════════════════════════════════════
//  TAB 3 — ALERTS / NOTIFICATION TESTER
// ═══════════════════════════════════════════════════════════════════════════════
class _AlertsTab extends StatelessWidget {
  final Future<void> Function(String) onTest;
  const _AlertsTab({required this.onTest});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

        // Info banner
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
          child: const Row(children: [
            Icon(Icons.notifications_active, color: AppColors.primary, size: 20),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Push notifications are sent to volunteers and admins in real-time. '
                'Use the testers below to preview each notification type.',
                style: TextStyle(fontSize: 12, color: AppColors.textPrimary)),
            ),
          ]),
        ),

        const SizedBox(height: 20),
        const _SectionHeader(icon: Icons.science, title: 'Notification Tester'),
        const SizedBox(height: 12),

        _NotifTestCard(
          type: 'urgent',
          icon: Icons.warning_amber,
          color: AppColors.urgencyHigh,
          title: 'Crisis Alert',
          subtitle: 'HIGH URGENCY broadcast to all volunteers',
          onTest: onTest,
        ),
        const SizedBox(height: 10),
        _NotifTestCard(
          type: 'assigned',
          icon: Icons.assignment_ind,
          color: AppColors.urgencyMedium,
          title: 'Task Assigned',
          subtitle: 'Volunteer gets notified of new assignment',
          onTest: onTest,
        ),
        const SizedBox(height: 10),
        _NotifTestCard(
          type: 'completed',
          icon: Icons.task_alt,
          color: AppColors.urgencyLow,
          title: 'Task Completed',
          subtitle: 'Admin notified when volunteer finishes',
          onTest: onTest,
        ),
        const SizedBox(height: 10),
        _NotifTestCard(
          type: 'reminder',
          icon: Icons.alarm,
          color: AppColors.secondary,
          title: 'Task Reminder',
          subtitle: 'Nudge sent if volunteer hasn\'t responded',
          onTest: onTest,
        ),

        const SizedBox(height: 24),
        const _SectionHeader(icon: Icons.settings_suggest, title: 'FCM Topics'),
        const SizedBox(height: 12),
        _TopicsCard(),

        const SizedBox(height: 24),
      ]),
    );
  }
}

class _NotifTestCard extends StatefulWidget {
  final String type, title, subtitle;
  final IconData icon;
  final Color color;
  final Future<void> Function(String) onTest;
  const _NotifTestCard({
    required this.type, required this.title, required this.subtitle,
    required this.icon, required this.color, required this.onTest,
  });
  @override
  State<_NotifTestCard> createState() => _NotifTestCardState();
}

class _NotifTestCardState extends State<_NotifTestCard> {
  bool _sending = false;

  Future<void> _send() async {
    setState(() => _sending = true);
    await widget.onTest(widget.type);
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(widget.icon, color: widget.color, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13)),
            Text(widget.subtitle, style: const TextStyle(
              fontSize: 11, color: AppColors.textSecondary)),
          ],
        )),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: ElevatedButton(
            onPressed: _sending ? null : _send,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
            ),
            child: _sending
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
              : const Text('Send', style: TextStyle(fontSize: 11)),
          ),
        ),
      ]),
    );
  }
}

class _TopicsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final topic in [
            ('admin_alerts',     'Admin alerts', AppColors.primary),
            ('volunteer_alerts', 'Volunteer alerts', AppColors.secondary),
            ('urgent',           'Urgent broadcasts', AppColors.urgencyHigh),
          ]) ...[
            Row(children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: topic.$3, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(topic.$1, style: const TextStyle(
                fontSize: 12, fontFamily: 'monospace')),
              const Spacer(),
              Text(topic.$2, style: const TextStyle(
                fontSize: 11, color: AppColors.textSecondary)),
            ]),
            if (topic.$1 != 'urgent') const Divider(height: 16),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  SHARED HELPERS
// ═══════════════════════════════════════════════════════════════════════════════
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: AppColors.primary),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final Color color;
  final IconData icon;
  final Widget child;
  const _StatCard({required this.color, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.78)],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
          color: color.withValues(alpha: 0.3),
          blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Stack(
        children: [
          Positioned(right: -4, top: -4,
            child: Icon(icon, size: 40,
              color: Colors.white.withValues(alpha: 0.12))),
          child,
        ],
      ),
    );
  }
}

class _EmptyChart extends StatelessWidget {
  const _EmptyChart();
  @override
  Widget build(BuildContext context) => Container(
    height: 80,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white, borderRadius: BorderRadius.circular(14)),
    child: const Text('No data yet', style: TextStyle(
      color: AppColors.textSecondary)),
  );
}

// ── Data models ──────────────────────────────────────────────────────────────
class _DailyCount {
  final String label;
  final int count;
  const _DailyCount({required this.label, required this.count});
}
