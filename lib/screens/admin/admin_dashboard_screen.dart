import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/needs_provider.dart'; // ✅ IMPORTANT
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_routes.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
@override
void initState() {
  super.initState();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    context.read<NeedsProvider>().startListening();
  });
}

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<AuthProvider>().signOut();

              if (context.mounted) {
                Navigator.pushReplacementNamed(
                  context,
                  AppRoutes.login,
                );
              }
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            Text(
              'Welcome, ${auth.currentUser?.name ?? "Admin"}!',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            const Text(
              'CrisisConnect Admin Panel',
              style: TextStyle(color: AppColors.textSecondary),
            ),

            const SizedBox(height: 32),

            // ✅ View all needs
            _DashboardButton(
              icon: Icons.list_alt,
              label: 'View All Needs',
              subtitle: 'See AI-prioritised list',
              color: AppColors.primary,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.needList,
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Report new need
            _DashboardButton(
              icon: Icons.add_circle,
              label: 'Report New Need',
              subtitle: 'AI scores it automatically',
              color: AppColors.secondary,
              onTap: () => Navigator.pushNamed(
                context,
                AppRoutes.addNeed,
              ),
            ),

            const SizedBox(height: 12),

            // ✅ Crisis Map — Day 6
            _DashboardButton(
              icon: Icons.map,
              label: 'Crisis Map',
              subtitle: 'Heatmap + color-coded urgency',
              color: const Color(0xFF6A1B9A),
              onTap: () => Navigator.pushNamed(context, AppRoutes.map),
            ),

            const SizedBox(height: 12),

            // ✅ Impact Tracker — Day 8
            _DashboardButton(
              icon: Icons.bar_chart,
              label: 'Impact Tracker',
              subtitle: 'Analytics, charts & notifications',
              color: const Color(0xFF00695C),
              onTap: () => Navigator.pushNamed(context, AppRoutes.impact),
            ),

            const SizedBox(height: 12),

            // ✅ AI Prediction Engine — Day 9
            _DashboardButton(
              icon: Icons.psychology,
              label: 'AI Prediction Engine',
              subtitle: 'Forecasts, escalation alerts & resource planning',
              color: const Color(0xFF4A148C),
              onTap: () => Navigator.pushNamed(context, AppRoutes.prediction),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ✅ Button widget (unchanged)
class _DashboardButton extends StatelessWidget {
  final IconData icon;
  final String label, subtitle;
  final Color color;
  final VoidCallback onTap;

  const _DashboardButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.arrow_forward_ios, color: color, size: 16),
              ],
            ),
          ),
        ),
      );
}
