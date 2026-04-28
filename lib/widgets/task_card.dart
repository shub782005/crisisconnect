import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../models/task_model.dart';
import '../models/need_model.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final NeedModel? need;
  final VoidCallback? onOnMyWay;
  final VoidCallback? onComplete;
  final bool isHistory;

  const TaskCard({
    super.key,
    required this.task,
    this.need,
    this.onOnMyWay,
    this.onComplete,
    this.isHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(task.status);
    final needType    = need?.type ?? 'unknown';
    final urgency     = need?.urgencyLevel ?? 'medium';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isHistory ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: isHistory
          ? BorderSide(color: Colors.grey.shade200)
          : BorderSide(color: statusColor.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Header row ──────────────────────────────────────────────────
          Row(children: [
            // Type icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.urgencyColor(urgency).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(needType),
                color: AppColors.urgencyColor(urgency), size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(needType.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
                if (need != null)
                  Text(need!.address,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
            // Status chip
            _StatusChip(status: task.status),
          ]),

          if (need != null) ...[
            const SizedBox(height: 10),
            Text(need!.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ],

          const SizedBox(height: 10),

          // ── Match score + AI reason ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              const Icon(Icons.auto_awesome, size: 12, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(task.matchReason,
                  style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
              ),
              Text('${(task.matchScore * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold,
                  color: AppColors.primary)),
            ]),
          ),

          // ── People affected ──────────────────────────────────────────────
          if (need != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.people, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('${need!.peopleAffected} people affected',
                style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
              const Spacer(),
              const Icon(Icons.access_time, size: 12, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(_timeAgo(task.assignedAt),
                style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
            ]),
          ],

          // ── Action buttons (active tasks only) ────────────────────────────
          if (!isHistory && task.status != 'completed') ...[
            const SizedBox(height: 12),
            Row(children: [
              if (task.status == 'assigned' && onOnMyWay != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onOnMyWay,
                    icon: const Icon(Icons.directions_run, size: 14),
                    label: const Text('On My Way', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.secondary,
                      side: const BorderSide(color: AppColors.secondary),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              if (task.status == 'assigned' && onOnMyWay != null && onComplete != null)
                const SizedBox(width: 8),
              if (onComplete != null)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(Icons.check_circle, size: 14),
                    label: const Text('Complete', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.urgencyLow,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ]),
          ],

          // ── Completed timestamp ──────────────────────────────────────────
          if (isHistory && task.completedAt != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.check_circle, size: 12, color: AppColors.urgencyLow),
              const SizedBox(width: 4),
              Text('Completed ${_timeAgo(task.completedAt!)}',
                style: const TextStyle(
                  fontSize: 11, color: AppColors.urgencyLow,
                  fontWeight: FontWeight.w500)),
            ]),
          ],
        ]),
      ),
    );
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'medical':  return Icons.local_hospital;
      case 'food':     return Icons.restaurant;
      case 'shelter':  return Icons.home;
      case 'water':    return Icons.water_drop;
      case 'clothing': return Icons.checkroom;
      default:         return Icons.help_outline;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'assigned':    return AppColors.assigned;
      case 'on_the_way':  return AppColors.inProgress;
      case 'completed':   return AppColors.completed;
      default:            return AppColors.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case 'assigned':   color = AppColors.assigned;   label = 'Assigned';   break;
      case 'on_the_way': color = AppColors.inProgress; label = 'En Route';   break;
      case 'completed':  color = AppColors.completed;  label = 'Done';       break;
      default:           color = AppColors.textSecondary; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
