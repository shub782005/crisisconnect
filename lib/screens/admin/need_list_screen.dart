import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/needs_provider.dart';
import '../../models/need_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../widgets/urgency_badge.dart';

class NeedListScreen extends StatelessWidget {
  const NeedListScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final needsProvider = context.watch<NeedsProvider>();
    final needs = needsProvider.needs;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Needs (${needs.length})'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.addNeed),
        icon: const Icon(Icons.add),
        label: const Text('Report Need'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: needs.isEmpty
        ? const Center(
            child: Column(mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inbox, size: 64,
                  color: AppColors.textSecondary),
                SizedBox(height: 12),
                Text('No needs reported yet',
                  style: TextStyle(color: AppColors.textSecondary)),
              ],
            ))
        : ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: needs.length,
            itemBuilder: (ctx, i) => _NeedCard(need: needs[i]),
          ),
    );
  }
}

class _NeedCard extends StatelessWidget {
  final NeedModel need;
  const _NeedCard({required this.need});
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: AppColors.urgencyColor(need.urgencyLevel).withValues(alpha: 0.3),
          width: 1)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              UrgencyBadge(level: need.urgencyLevel),
              const SizedBox(width: 8),
              Text(need.type.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold,
                  fontSize: 13, color: AppColors.textPrimary)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(
                  'AI: ${(need.priorityScore * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 11,
                    fontWeight: FontWeight.bold, color: AppColors.primary)),
              ),
            ]),
            const SizedBox(height: 8),
            Text(need.description, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.people, size: 14,
                color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${need.peopleAffected} people',
                style: const TextStyle(fontSize: 12,
                  color: AppColors.textSecondary)),
              const SizedBox(width: 12),
              const Icon(Icons.location_on, size: 14,
                color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(child: Text(need.address,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12,
                  color: AppColors.textSecondary))),
            ]),
            const SizedBox(height: 8),
            _StatusChip(status: need.status),
            // Add this after _StatusChip(status: need.status):
if (need.status == 'pending') ...[
  const SizedBox(height: 8),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: () => Navigator.pushNamed(
        context,
        AppRoutes.assignVolunteer,
        arguments: need,
      ),
      icon: const Icon(Icons.person_search, size: 16),
      label: const Text('AI Match Volunteer'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary)),
    ),
  ),
],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});
  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'pending': color = AppColors.pending; break;
      case 'assigned': color = AppColors.assigned; break;
      case 'completed': color = AppColors.completed; break;
      default: color = AppColors.textSecondary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(status.toUpperCase(),
        style: TextStyle(fontSize: 10,
          fontWeight: FontWeight.bold, color: color)),
    );
  }
}