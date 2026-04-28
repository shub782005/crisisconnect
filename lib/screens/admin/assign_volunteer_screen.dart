import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/need_model.dart';
import '../../providers/volunteer_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/matching_service.dart';
import '../../core/constants/app_colors.dart';
import '../../widgets/urgency_badge.dart';

class AssignVolunteerScreen extends StatefulWidget {
  final NeedModel need;
  const AssignVolunteerScreen({super.key,
    required this.need});
  @override
  State<AssignVolunteerScreen> createState() =>
    _AssignVolunteerScreenState();
}

class _AssignVolunteerScreenState
    extends State<AssignVolunteerScreen> {
  List<MatchResult> _matches = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadMatches();
      }
    });
  }

  Future<void> _loadMatches() async {
    final vp = context.read<VolunteerProvider>();
    await vp.loadVolunteers();
    setState(() {
      _matches = vp.getBestMatches(widget.need);
      _loading = false;
    });
  }

  Future<void> _assign(MatchResult match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Assignment'),
        content: Text('Assign ${match.volunteerName} to this need?\n\n${match.explanation}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary),
            child: const Text('Assign',
              style: TextStyle(color: Colors.white))),
        ],
      ));
    if (confirmed == true && mounted) {
      final success = await context.read<TaskProvider>()
        .assignTask(need: widget.need, match: match);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${match.volunteerName} assigned!'),
          backgroundColor: AppColors.urgencyLow,
        ));
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Volunteer Matching'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : Column(children: [
            // Need summary header
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.06),
              child: Row(children: [
                UrgencyBadge(level: widget.need.urgencyLevel),
                const SizedBox(width: 10),
                Expanded(child: Text(widget.need.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
              ]),
            ),
            // Matches list
            _matches.isEmpty
              ? const Expanded(child: Center(
                  child: Text('No available volunteers.\nAdd volunteers first.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary))))
              : Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _matches.length,
                    itemBuilder: (ctx, i) =>
                      _MatchCard(
                        match: _matches[i],
                        rank: i + 1,
                        onAssign: () => _assign(_matches[i]),
                      ),
                  ),
              ),
          ]),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final MatchResult match;
  final int rank;
  final VoidCallback onAssign;
  const _MatchCard({required this.match,
    required this.rank, required this.onAssign});

  @override
  Widget build(BuildContext context) {
    final isTop = rank == 1;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isTop ? 3 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isTop ? AppColors.primary : Colors.transparent,
          width: 1.5)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Rank badge
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  color: isTop ? AppColors.primary : Colors.grey.shade200,
                  shape: BoxShape.circle),
                child: Center(child: Text('#$rank',
                  style: TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isTop ? Colors.white : Colors.grey))),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(match.volunteerName,
                style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 15))),
              // Match score %
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'Match: ${(match.matchScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary)),
              ),
            ]),
            const SizedBox(height: 8),
            // Explainability — THE key feature
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.auto_awesome,
                  size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(child: Text(match.explanation,
                  style: const TextStyle(fontSize: 12,
                    color: AppColors.textSecondary))),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAssign,
                icon: const Icon(Icons.person_add, size: 16),
                label: Text(isTop
                  ? 'Assign Best Match'
                  : 'Assign This Volunteer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isTop
                    ? AppColors.primary
                    : AppColors.secondary,
                  foregroundColor: Colors.white),
              )),
          ],
        ),
      ),
    );
  }
}