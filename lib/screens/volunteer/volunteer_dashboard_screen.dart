import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/needs_provider.dart';
import '../../models/task_model.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';
import '../../widgets/urgency_badge.dart';

class VolunteerDashboardScreen extends StatefulWidget {
  const VolunteerDashboardScreen({super.key});
  @override
  State<VolunteerDashboardScreen> createState() =>
    _VolunteerDashboardScreenState();
}

class _VolunteerDashboardScreenState
    extends State<VolunteerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final uid = context.read<AuthProvider>()
      .currentUser?.id ?? '';
    context.read<TaskProvider>()
      .startListeningForVolunteer(uid);
    context.read<NeedsProvider>().startListening();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.tasks;
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.map),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.map, size: 18),
        label: const Text('Crisis Map'),
      ),
      appBar: AppBar(
        title: const Text('My Tasks'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [IconButton(
          icon: const Icon(Icons.logout),
          onPressed: () async {
            await auth.signOut();
            if (mounted) {
              Navigator.pushReplacementNamed(
                // ignore: use_build_context_synchronously
                context, AppRoutes.login);
            }
          })],
      ),
      body: Column(children: [
        // Welcome banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          color: AppColors.secondary.withValues(alpha: 0.08),
          child: Row(children: [
            const Icon(Icons.volunteer_activism,
              color: AppColors.secondary),
            const SizedBox(width: 10),
            Text('Hi, ${auth.currentUser?.name ?? "Volunteer"}!',
              style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(20)),
              child: Text('${tasks.length} task${tasks.length == 1 ? "" : "s"}',
                style: const TextStyle(color: Colors.white,
                  fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // Tasks list
        tasks.isEmpty
          ? const Expanded(child: Center(
              child: Column(mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt, size: 64,
                    color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text('No tasks assigned yet',
                    style: TextStyle(color: AppColors.textSecondary)),
                  Text('You will be notified when assigned',
                    style: TextStyle(fontSize: 12,
                      color: AppColors.textSecondary)),
                ])))
          : Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: tasks.length,
                itemBuilder: (ctx, i) =>
                  _TaskCard(task: tasks[i]),
              )),
      ]),
    );
  }
}

class _TaskCard extends StatelessWidget {
  final TaskModel task;
  const _TaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final need = context.read<NeedsProvider>()
      .needs.where((n) => n.id == task.needId)
      .firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (need != null) ...[
              Row(children: [
                UrgencyBadge(level: need.urgencyLevel),
                const SizedBox(width: 8),
                Text(need.type.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 6),
              Text(need.description,
                style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on, size: 13,
                  color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(need.address,
                  style: const TextStyle(fontSize: 12,
                    color: AppColors.textSecondary)),
              ]),
            ],
            const SizedBox(height: 8),
            // AI match reason
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(6)),
              child: Row(children: [
                const Icon(Icons.auto_awesome, size: 12,
                  color: AppColors.secondary),
                const SizedBox(width: 6),
                Expanded(child: Text(task.matchReason,
                  style: const TextStyle(fontSize: 11,
                    color: AppColors.secondary))),
              ]),
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(children: [
              if (task.status == 'assigned')
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => context
                    .read<TaskProvider>()
                    .updateTaskStatus(task.id, 'on_the_way'),
                  icon: const Icon(Icons.directions_run, size: 16),
                  label: const Text('On My Way'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                    foregroundColor: Colors.white))),
              if (task.status == 'on_the_way') ...[
                Expanded(child: ElevatedButton.icon(
                  onPressed: () => context
                    .read<TaskProvider>()
                    .updateTaskStatus(task.id, 'completed'),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Mark Complete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.urgencyLow,
                    foregroundColor: Colors.white))),
              ],
            ]),
          ],
        ),
      ),
    );
  }
}