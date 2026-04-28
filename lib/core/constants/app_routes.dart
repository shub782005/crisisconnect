import 'package:flutter/material.dart';
import '../../../screens/auth/login_screen.dart';
import '../../../screens/auth/signup_screen.dart';
import '../../../screens/admin/admin_dashboard_screen.dart';
import '../../../screens/volunteer/volunteer_dashboard_screen.dart';
import '../../../screens/admin/need_list_screen.dart';
import '../../../screens/admin/add_need_screen.dart';
// ignore: unused_import
import '../../../screens/admin/assign_volunteer_screen.dart';
import '../../../screens/map/crisis_map_screen.dart';
import '../../../screens/admin/impact_analytics_screen.dart';
import '../../../screens/admin/prediction_screen.dart';

  
class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String adminDashboard = '/admin';
  static const String volunteerDashboard = '/volunteer';
  static const String needList = '/needs';
  static const String addNeed = '/needs/add';
  static const String map = '/map';
  static const String assignVolunteer = '/assign'; 
  static const String impact           = '/impact';
  static const String prediction       = '/prediction';

  static final Map<String, WidgetBuilder> routes = {
    splash: (_) => const SplashScreen(),
    login: (_) => const LoginScreen(),
    signup: (_) => const SignupScreen(),
    adminDashboard: (_) => const AdminDashboardScreen(),
    volunteerDashboard: (_) => const VolunteerDashboardScreen(),
    needList: (_) => const NeedListScreen(),
    addNeed: (_) => const AddNeedScreen(),
    map: (_) => const CrisisMapScreen(),
    impact: (_) => const ImpactAnalyticsScreen(),
    prediction:  (_) => const PredictionScreen(),
  };
}

// Splash navigates to login after 2 seconds
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-navigate to login after 2.5 seconds
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1565C0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.crisis_alert, size: 80, color: Colors.white),
            SizedBox(height: 24),
            Text('CrisisConnect', style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.bold,
              color: Colors.white)),
            SizedBox(height: 8),
            Text('Disaster Relief Coordination',
              style: TextStyle(fontSize: 16, color: Colors.white70)),
            SizedBox(height: 48),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}